//
//  DownloadedCache.swift
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
public actor DownloadedCache<DownloadedElement: CacheableElement>: DownloadedCacheProtocol {
	let _item: CurrentValueSubject<DownloadedElement?, Never> = .init(nil)
	public nonisolated var content: DownloadedElement? { _item.value }
	public private(set) var cacheName: String?
	public var fileWatcher: FileWatcher?
	var redirect: TaskRedirect?

	var updateClosure: UpdateClosure?
	var notificationObservers: [Any] = []

	init<Downloader: PayloadDownloadingTask>(downloader: Downloader, cacheName: String? = String(describing: DownloadedElement.self) + "_cache.json", redirect: TaskRedirect? = nil, refresh: CacheRefreshTiming = .atStartup) where Downloader.DownloadPayload == DownloadedElement {
	
		if let redirect, let other = downloader.wrappedRedirect, redirect != other {
			print("Redirect mismatch for \(downloader): \(redirect) != \(other)")
		}
		self.init(cacheName: cacheName, redirect: redirect, refresh: refresh, update: Self.buildRefreshClosure(for: downloader))
	}
	
	static func buildRefreshClosure<Downloader: PayloadDownloadingTask>(for downloader: Downloader, redirects: TaskRedirect? = nil) -> UpdateClosure where Downloader.DownloadPayload == DownloadedElement {
		
		{
		  try await downloader
			  .redirects(redirects)
			  .download()
	  }
	}
	
	func updateRefreshClosure<Downloader: PayloadDownloadingTask>(for downloader: Downloader, redirects: TaskRedirect? = nil) where Downloader.DownloadPayload == DownloadedElement {
		
		updateClosure = Self.buildRefreshClosure(for: downloader, redirects: redirects)
	}
	
	init(cacheName: String? = String(describing: DownloadedElement.self) + "_cache.json", redirect: TaskRedirect? = nil, refresh: CacheRefreshTiming = .atStartup, update: UpdateClosure? = nil) {
		self.cacheName = cacheName
		self.updateClosure = update
		self.redirect = redirect
		updateRefreshment(redirect: redirect, refresh: refresh)
	}
	
	public nonisolated func clear() {
		_item.value = nil
		Task { try? await saveToCache() }
	}
	
	public func load(_ newItem: DownloadedElement?) {
		if _item.value != newItem {
			_item.send(newItem)
			Task { @MainActor in self.objectWillChange.send() }
		}
	}
}
