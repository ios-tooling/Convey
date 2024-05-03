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

struct NonfunctionalDownloadTask<DownloadedElement: CacheableElement>: PayloadDownloadingTask {
	typealias DownloadPayload = NonfunctionalWrapper

	var path: String { "" }
	struct NonfunctionalWrapper: WrappedDownloadArray {
		typealias Element = DownloadedElement
		
		static var wrappedKeypath: KeyPath<Self, [DownloadedElement]> { \.wrapped }
		var wrapped: [DownloadedElement]
	}
	
	
}

/// This cache is linked to an individual codable type, but is pre-loaded with a refreshing task

@available(iOS 13, macOS 13, watchOS 8, visionOS 1, *)
public actor TaskBasedCodableArrayCache<Downloader: PayloadDownloadingTask, DownloadedElement: CacheableElement>: DownloadedElementCache where Downloader.DownloadPayload: WrappedDownloadArray, Downloader.DownloadPayload.Element == DownloadedElement {
	let _items: CurrentValueSubject<[DownloadedElement], Never> = .init([])
	public nonisolated var items: [DownloadedElement] { _items.value }
	public private(set) var cacheName: String?
	public var fileWatcher: FileWatcher?
	var redirect: TaskRedirect?

	var updateTask: Downloader
	var notificationObservers: [Any] = []

	init(updateTask: Downloader, cacheName: String? = String(describing: DownloadedElement.self) + "_cache.json", redirect: TaskRedirect? = nil, refresh: CacheRefreshTiming = .atStartup) {
		self.cacheName = cacheName
		self.updateTask = updateTask
		self.redirect = redirect
		Task {
			await setupRedirect(redirect ?? updateTask.wrappedRedirect)
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
	
	public func load(items newItems: [DownloadedElement]) {
		if _items.value != newItems {
			_items.send(newItems)
			Task { @MainActor in self.objectWillChange.send() }
		}
	}
	
	func addObserver(_ observer: Any) { notificationObservers.append(observer) }
	nonisolated func refresh(on name: Notification.Name) {
		Task { await addObserver(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main, using: { note in self.nonisolatedRefresh(note) })) }
	}
	
	public func refresh() async throws {
		let task = updateTask
			.redirects(redirect)
		load(items: try await task.downloadArray())
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

extension TaskBasedCodableArrayCache where Downloader == NonfunctionalDownloadTask<DownloadedElement> {
	init(cacheName: String? = String(describing: DownloadedElement.self) + "_cache.json", redirect: TaskRedirect? = nil) {
		self.init(updateTask: NonfunctionalDownloadTask(), cacheName: cacheName, redirect: redirect, refresh: [])
	}
}
