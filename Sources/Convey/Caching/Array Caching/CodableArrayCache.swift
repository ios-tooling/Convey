//
//  LocalElementCache.swift
//
//
//  Created by Ben Gottlieb on 5/2/24.
//

import Foundation
import Combine

#if canImport(UIKit)
	import UIKit
#endif

struct PlaceholderTask<DownloadedElement: CacheableElement>: PayloadDownloadingTask {
	typealias DownloadPayload = NonfunctionalWrapper

	var path: String { "" }
	struct NonfunctionalWrapper: WrappedDownloadArray {
		typealias Element = DownloadedElement
		
		static var wrappedKeypath: KeyPath<Self, [DownloadedElement]> { \.wrapped }
		var wrapped: [DownloadedElement]
	}
}

/// This cache is linked to an individual codable type, and is pre-loaded with a refreshing closure. It can automatically refresh in response to certain system events (app launch, resume, etc)

@available(iOS 13, macOS 13, watchOS 8, visionOS 1, *)
public actor CodableArrayCache<DownloadedElement: CacheableElement>: DownloadedElementCache {
	let _items: CurrentValueSubject<[DownloadedElement], Never> = .init([])
	public nonisolated var items: [DownloadedElement] { _items.value }
	public private(set) var cacheName: String?
	public var fileWatcher: FileWatcher?
	var redirect: TaskRedirect?

	var updateClosure: (() async throws -> [DownloadedElement])?
	var notificationObservers: [Any] = []

	init<Downloader: PayloadDownloadingTask>(downloader: Downloader, cacheName: String? = String(describing: DownloadedElement.self) + "_cache.json", redirect: TaskRedirect? = nil, refresh: CacheRefreshTiming = .atStartup) where Downloader.DownloadPayload: WrappedDownloadArray, Downloader.DownloadPayload.Element == DownloadedElement {
	
		if let redirect, let other = downloader.wrappedRedirect, redirect != other {
			print("Redirect mismatch for \(downloader): \(redirect) != \(other)")
		}
		self.init(cacheName: cacheName, redirect: redirect, refresh: refresh, update: Self.buildRefreshClosure(for: downloader))
	}
	
	static func buildRefreshClosure<Downloader: PayloadDownloadingTask>(for downloader: Downloader, redirects: TaskRedirect? = nil) -> (() async throws -> [DownloadedElement]) where Downloader.DownloadPayload: WrappedDownloadArray, Downloader.DownloadPayload.Element == DownloadedElement {
		
		{
		  try await downloader
			  .redirects(redirects)
			  .downloadArray()
	  }
	}
	
	func updateRefreshClosure<Downloader: PayloadDownloadingTask>(for downloader: Downloader, redirects: TaskRedirect? = nil) where Downloader.DownloadPayload: WrappedDownloadArray, Downloader.DownloadPayload.Element == DownloadedElement {
		
		updateClosure = Self.buildRefreshClosure(for: downloader, redirects: redirects)
	}
	
	init(cacheName: String? = String(describing: DownloadedElement.self) + "_cache.json", redirect: TaskRedirect? = nil, refresh: CacheRefreshTiming = .atStartup, update: (() async throws -> [DownloadedElement])? = nil) {
		self.cacheName = cacheName
		self.updateClosure = update
		self.redirect = redirect
		Task {
			await setupRedirect(redirect)
			await loadFromCache()
			if refresh.contains(.atStartup) { try? await self.refresh() }
			#if os(iOS)
				if refresh.contains(.atResume) { await self.refresh(on: UIApplication.didBecomeActiveNotification) }
			#endif

			if refresh.contains(.atSignIn) { self.refresh(on: .conveyDidSignInNotification) }
			if refresh.contains(.atSignOut) { self.refresh(on: .conveyDidSignOutNotification) }
		}
	}

	public func refresh<NewDownloader: PayloadDownloadingTask>(from task: NewDownloader) async throws where NewDownloader.DownloadPayload: WrappedDownloadArray, NewDownloader.DownloadPayload.Element == DownloadedElement {
		load(items: try await task.downloadArray())
		try saveToCache()
	}
	
	public nonisolated func clear() {
		_items.value = []
		Task { try? await saveToCache() }
	}
	
	public func load(items newItems: [DownloadedElement]) {
		if _items.value != newItems {
			_items.send(newItems)
			Task { @MainActor in self.objectWillChange.send() }
		}
	}
	
	func addObserver(_ observer: Any) { notificationObservers.append(observer) }
	nonisolated func refresh(on name: Notification.Name) {
		if name == .conveyDidSignOutNotification {
			clear()
		} else {
			Task { await addObserver(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main, using: { note in self.nonisolatedRefresh(note) })) }
		}
	}
	
	public func refresh() async throws {
		guard let updateClosure else { return }
		load(items: try await updateClosure())
		try saveToCache()
	}
	
	public nonisolated func nonisolatedRefresh(_ note: Notification) {
		print("Received \(note)")

		Task {
			do {
				try await refresh()
			} catch {
				print("Error during refresh of \(String(describing: DownloadedElement.self)) cache: \(error)")
			}
		}
	}
}
