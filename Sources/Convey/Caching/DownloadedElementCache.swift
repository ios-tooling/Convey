//
//  DownloadedElementCache.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 4/28/24.
//

import Foundation
import Combine

public typealias CacheableElement = Codable & Equatable & Sendable

public protocol DownloadedElementCache<DownloadedElement>: Actor, ObservableObject {
	associatedtype DownloadedElement: CacheableElement
	
	func load(items newItems: [DownloadedElement])
	func refresh() async throws
	func refresh<NewDownloader: PayloadDownloadingTask>(from task: NewDownloader) async throws -> Void where NewDownloader.DownloadPayload: WrappedDownloadArray, NewDownloader.DownloadPayload.Element == DownloadedElement
	
	nonisolated func setup()
	nonisolated var items: [DownloadedElement] { get }
	var cacheLocation: URL? { get }
}

public extension DownloadedElementCache {
	var cacheLocation: URL? {
		FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent(String(describing: DownloadedElement.self) + "_cache.json")
	}
	
	func saveToCache() throws {
		guard let cacheLocation else { return }
		let data = try JSONEncoder().encode(items)
		try data.write(to: cacheLocation, options: .atomic)
	}
	
	nonisolated func setup() { }
	func loadFromCache() {
		guard let cacheLocation else { return }
		do {
			let data = try Data(contentsOf: cacheLocation)
			let items = try JSONDecoder().decode([DownloadedElement].self, from: data)
			load(items: items)
		} catch {
			print("Failed to load \(DownloadedElement.self) from \(cacheLocation.path)")
		}
	}
}

@available(iOS 13, macOS 13, watchOS 8, visionOS 1, *)
actor LocalElementCache<DownloadedElement: CacheableElement>: DownloadedElementCache {
	let _items: CurrentValueSubject<[DownloadedElement], Never> = .init([])
	public nonisolated var items: [DownloadedElement] { _items.value }

	public func refresh<NewDownloader: PayloadDownloadingTask>(from task: NewDownloader) async throws where NewDownloader.DownloadPayload: WrappedDownloadArray, NewDownloader.DownloadPayload.Element == DownloadedElement {
		load(items: try await task.downloadArray())
		try saveToCache()
	}
	
	init() {
		Task { await loadFromCache() }
	}
	
	nonisolated func setup() { }
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


@available(iOS 13, macOS 13, watchOS 8, visionOS 1, *)
actor PayloadDownloadedElementCache<Downloader: PayloadDownloadingTask, DownloadedElement: CacheableElement>: DownloadedElementCache where Downloader.DownloadPayload: WrappedDownloadArray, Downloader.DownloadPayload.Element == DownloadedElement {
	let _items: CurrentValueSubject<[DownloadedElement], Never> = .init([])
	public nonisolated var items: [DownloadedElement] { _items.value }

	var updateTask: Downloader
	var redirect: TaskRedirect?
	
	init(updateTask: Downloader) {
		self.updateTask = updateTask
		Task { await loadFromCache() }
	}
	
	func setRedirect(_ redirect: TaskRedirect?) async throws {
		self.redirect = redirect
		try await refresh()
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
			.redirects(redirect)
		
		load(items: try await task.downloadArray())
		try saveToCache()
	}
}
