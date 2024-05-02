//
//  LocalElementCache.swift
//
//
//  Created by Ben Gottlieb on 5/2/24.
//

import Foundation
import Combine

/// This cache is linked to an individual codable type. If initialized with a nil-cacheName, it will not be persisted to disk

@available(iOS 13, macOS 13, watchOS 8, visionOS 1, *)
public actor CodableArrayCache<DownloadedElement: CacheableElement>: DownloadedElementCache {
	let _items: CurrentValueSubject<[DownloadedElement], Never> = .init([])
	public nonisolated var items: [DownloadedElement] { _items.value }
	public private(set) var cacheName: String?

	public func refresh<NewDownloader: PayloadDownloadingTask>(from task: NewDownloader) async throws where NewDownloader.DownloadPayload: WrappedDownloadArray, NewDownloader.DownloadPayload.Element == DownloadedElement {
		load(items: try await task.downloadArray())
		try saveToCache()
	}
	
	public init(cacheName: String? = String(describing: DownloadedElement.self) + "_cache.json", redirect: TaskRedirect? = nil) {
		self.cacheName = cacheName
		Task {
			await setupRedirect(redirect)
			await loadFromCache()
		}
	}
	
	public nonisolated func setup() { }
	public func load(items newItems: [DownloadedElement]) {
		if _items.value != newItems {
			_items.send(newItems)
			Task { @MainActor in self.objectWillChange.send() }
		}
	}
	
	public func refresh() async throws {
		print("Refreshing a LocalElementCache is not supported")
	}
}


/// This cache is linked to an individual codable type, but is pre-loaded with a refreshing task

@available(iOS 13, macOS 13, watchOS 8, visionOS 1, *)
public actor TaskBasedCodableArrayCache<Downloader: PayloadDownloadingTask, DownloadedElement: CacheableElement>: DownloadedElementCache where Downloader.DownloadPayload: WrappedDownloadArray, Downloader.DownloadPayload.Element == DownloadedElement {
	let _items: CurrentValueSubject<[DownloadedElement], Never> = .init([])
	public nonisolated var items: [DownloadedElement] { _items.value }
	public private(set) var cacheName: String?

	var updateTask: Downloader
	
	init(updateTask: Downloader, cacheName: String? = String(describing: DownloadedElement.self) + "_cache.json", redirect: TaskRedirect? = nil) {
		self.cacheName = cacheName
		self.updateTask = updateTask
		Task {
			await setupRedirect(redirect ?? updateTask.wrappedRedirect)
			await loadFromCache()
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
	
	public func refresh() async throws {
		let task = updateTask
		
		load(items: try await task.downloadArray())
		try saveToCache()
	}
}
