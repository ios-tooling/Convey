//
//  DownloadArrayCache.swift
//
//
//  Created by Ben Gottlieb on 5/2/24.
//

import Foundation
import Combine

/// This cache is linked to an individual codable type, and is pre-loaded with a reloading closure. It can automatically refresh in response to certain system events (app launch, resume, etc)

@available(iOS 13, macOS 13, watchOS 8, visionOS 1, *)
public actor DownloadArrayCache<DownloadedElement: CacheableContent>: DownloadedArrayCacheProtocol {
	public typealias UpdateClosure = (() async throws -> [DownloadedElement]?)

	let _items: CurrentValueSubject<[DownloadedElement]?, Never> = .init([])
	public nonisolated var content: [DownloadedElement]? { _items.value }
	public private(set) var cacheName: String
	public var fileWatcher: FileWatcher?
	public var redirect: TaskRedirect?
	public nonisolated var items: [DownloadedElement] { content ?? [] }

	public var updateClosure: UpdateClosure?
	public var notificationObservers: [Any] = []

	init<Downloader: PayloadDownloadingTask>(downloader: Downloader, cacheName: String? = nil, redirect: TaskRedirect? = nil, refresh: CacheRefreshTiming = .atStartup) where Downloader.DownloadPayload: WrappedDownloadArray, Downloader.DownloadPayload.Element == DownloadedElement {
	
		if let redirect, let other = downloader.wrappedRedirect, redirect != other {
			print("Redirect mismatch for \(downloader): \(redirect) != \(other)")
		}
		self.init(cacheName: cacheName, redirect: redirect ?? downloader.wrappedRedirect, refresh: refresh, update: Self.buildRefreshClosure(for: downloader, redirects: redirect))
	}
	
	static func buildRefreshClosure<Downloader: PayloadDownloadingTask>(for downloader: Downloader, redirects: TaskRedirect? = nil) -> UpdateClosure where Downloader.DownloadPayload: WrappedDownloadArray, Downloader.DownloadPayload.Element == DownloadedElement {

		return {
		  try await downloader
			  .redirects(redirects)
			  .downloadArray()
	  }
	}
	
	func updateRefreshClosure<Downloader: PayloadDownloadingTask>(for downloader: Downloader, redirects: TaskRedirect? = nil) where Downloader.DownloadPayload: WrappedDownloadArray, Downloader.DownloadPayload.Element == DownloadedElement {
		
		updateClosure = Self.buildRefreshClosure(for: downloader, redirects: redirects)
	}
	
	init(cacheName: String? = nil, redirect: TaskRedirect? = nil, refresh: CacheRefreshTiming = .atStartup, update: UpdateClosure? = nil) {
		self.cacheName = cacheName ?? String(describing: DownloadedItem.self) + "_cache"
		self.updateClosure = update
		self.redirect = redirect
		updateRefreshment(redirect: redirect, refresh: refresh)
	}

	public func refresh<NewDownloader: PayloadDownloadingTask>(from task: NewDownloader) async throws where NewDownloader.DownloadPayload: WrappedDownloadArray, NewDownloader.DownloadPayload.Element == DownloadedElement {
		load(try await task.downloadArray())
		try saveToCache()
	}
	
	public nonisolated func clear() {
		_items.value = []
		Task { try? await saveToCache() }
	}
	
	public func load(_ newItems: [DownloadedElement]?) {
		if _items.value != newItems {
			_items.send(newItems)
			Task { @MainActor in self.objectWillChange.send() }
		}
	}

	public func refresh(closure: (@Sendable () async throws -> [DownloadedElement]?)? = nil) async throws {
		guard let refresh = closure ?? updateClosure else { return }
		load(try await refresh())
		try saveToCache()
	}
	
	public nonisolated func nonisolatedRefresh(_ note: Notification) {
		print("Received \(note)")
		if note.name == .conveyDidSignOutNotification {
			clear()
		} else {
			Task {
				do {
					try await refresh()
				} catch {
					print("Error during refresh of \(String(describing: DownloadedElement.self)) cache: \(error)")
				}
			}
		}
	}
}
