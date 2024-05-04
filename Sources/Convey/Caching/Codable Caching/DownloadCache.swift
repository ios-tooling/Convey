//
//  DownloadCache.swift
//
//
//  Created by Ben Gottlieb on 5/3/24.
//

import Foundation
import Combine

#if canImport(UIKit)
	import UIKit
#endif

@available(iOS 13, macOS 13, watchOS 8, visionOS 1, *)
public actor DownloadCache<DownloadedContent: CacheableContent>: DownloadedCacheProtocol {
	public typealias UpdateClosure = (() async throws -> DownloadedContent?)

	let _item: CurrentValueSubject<DownloadedContent?, Never> = .init(nil)
	public nonisolated var content: DownloadedContent? { _item.value }
	public private(set) var cacheName: String
	public var fileWatcher: FileWatcher?
	public var redirect: TaskRedirect?

	public var updateClosure: UpdateClosure?
	public var notificationObservers: [Any] = []

	init<Downloader: PayloadDownloadingTask>(wrappedDownloader downloader: Downloader, cacheName: String? = nil, redirect: TaskRedirect? = nil, refresh: CacheRefreshTiming = .atStartup) where Downloader.DownloadPayload: CacheableContainer, Downloader.DownloadPayload.ContainedContent == DownloadedContent {
	
		if let redirect, let other = downloader.wrappedRedirect, redirect != other {
			print("Redirect mismatch for \(downloader): \(redirect) != \(other)")
		}
		self.init(cacheName: cacheName, redirect: redirect ?? downloader.wrappedRedirect, refresh: refresh, update: Self.buildRefreshClosure(for: downloader, redirects: redirect))
	}

	init<Downloader: PayloadDownloadingTask>(downloader: Downloader, cacheName: String? = nil, redirect: TaskRedirect? = nil, refresh: CacheRefreshTiming = .atStartup) where Downloader.DownloadPayload == DownloadedContent {
	
		if let redirect, let other = downloader.wrappedRedirect, redirect != other {
			print("Redirect mismatch for \(downloader): \(redirect) != \(other)")
		}
		self.init(cacheName: cacheName, redirect: redirect, refresh: refresh, update: Self.buildRefreshClosure(for: downloader))
	}
	
	static func buildRefreshClosure<Downloader: PayloadDownloadingTask>(for downloader: Downloader, redirects: TaskRedirect? = nil) -> UpdateClosure where Downloader.DownloadPayload == DownloadedContent {
		
		{
		  try await downloader
			  .redirects(redirects)
			  .download()
	  }
	}
	
	static func buildRefreshClosure<Downloader: PayloadDownloadingTask>(for downloader: Downloader, redirects: TaskRedirect? = nil) -> UpdateClosure where Downloader.DownloadPayload: CacheableContainer, Downloader.DownloadPayload.ContainedContent == DownloadedContent {
		
		{
		  try await downloader
			  .redirects(redirects)
			  .downloadItem()
	  }
	}
	
	func updateRefreshClosure<Downloader: PayloadDownloadingTask>(for downloader: Downloader, redirects: TaskRedirect? = nil) where Downloader.DownloadPayload == DownloadedContent {
		
		updateClosure = Self.buildRefreshClosure(for: downloader, redirects: redirects)
	}
	
	func updateRefreshClosure<Downloader: PayloadDownloadingTask>(for downloader: Downloader, redirects: TaskRedirect? = nil) where Downloader.DownloadPayload: CacheableContainer, Downloader.DownloadPayload.ContainedContent == DownloadedContent {
		
		updateClosure = Self.buildRefreshClosure(for: downloader, redirects: redirects)
	}
	
	init(cacheName: String? = nil, redirect: TaskRedirect? = nil, refresh: CacheRefreshTiming = .atStartup, update: UpdateClosure? = nil) {
		self.cacheName = cacheName ?? String(describing: DownloadedContent.self) + "_cache"
		self.updateClosure = update
		self.redirect = redirect
		updateRefreshment(redirect: redirect, refresh: refresh)
	}
	
	public nonisolated func clear() {
		_item.value = nil
		Task { try? await saveToCache() }
	}
	
	public func load(_ newItem: DownloadedContent?) {
		if _item.value != newItem {
			_item.send(newItem)
			Task { @MainActor in self.objectWillChange.send() }
		}
	}
}
