//
//  DownloadedElementCacheManager.swift
//
//
//  Created by Ben Gottlieb on 5/2/24.
//

import Foundation
import Combine

@available(iOS 16, macOS 13, watchOS 9, *)
public actor ElementCache<Element: CacheableElement>: DownloadedElementCache {
	let wrapped: any DownloadedElementCache<Element>
	
	var observer: AnyCancellable?
	
	init(wrapped: any DownloadedElementCache<Element>) {
		self.wrapped = wrapped
		Task { await setupWrapper() }
	}
	
	func setupWrapper() {
		observer = (self.wrapped.objectWillChange as? ObservableObjectPublisher)?
			.receive(on: RunLoop.main)
			.sink { _ in
				self.objectWillChange.send()
			}
	}
	
	public func load(items newItems: [Element]) { Task { await wrapped.load(items: items) }}
	public func refresh() async throws { try await wrapped.refresh() }
	public func refresh<NewDownloader: PayloadDownloadingTask>(from task: NewDownloader) async throws -> Void where NewDownloader.DownloadPayload: WrappedDownloadArray, NewDownloader.DownloadPayload.Element == Element {
		try await wrapped.refresh(from: task)
	}
	
	public nonisolated var items: [Element] { wrapped.items }
	public var cacheLocation: URL? { nil }
	public nonisolated func setup() { wrapped.setup() }
}


@available(iOS 16, macOS 13, watchOS 9, *)
public extension Decodable where Self: CacheableElement {
	static var downloadedCache: ElementCache<Self> { DownloadedElementCacheManager.instance.fetchCache() }
	static func downloadedCache<Downloader: PayloadDownloadingTask>(_ downloader: Downloader) -> ElementCache<Self> where Downloader.DownloadPayload: WrappedDownloadArray, Downloader.DownloadPayload.Element == Self { DownloadedElementCacheManager.instance.fetchCache(downloader) }
}

@available(iOS 16, macOS 13, watchOS 9, *)
public class DownloadedElementCacheManager {
	public static let instance = DownloadedElementCacheManager()
	
	var caches: [String: any DownloadedElementCache] = [:]
	
	func fetchCache<Downloader: PayloadDownloadingTask, DownloadedElement: CacheableElement>(_ downloader: Downloader) -> (ElementCache<DownloadedElement>) where Downloader.DownloadPayload: WrappedDownloadArray, Downloader.DownloadPayload.Element == DownloadedElement {
		if let cache = caches[DownloadedElement.cacheKey] as? ElementCache<DownloadedElement> { return cache }
		
		let cache = PayloadDownloadedElementCache(updateTask: downloader)
		let wrapped = ElementCache(wrapped: cache)
		caches[DownloadedElement.cacheKey] = wrapped
		return wrapped
	}
	
	func fetchCache<DownloadedElement: CacheableElement>() -> ElementCache<DownloadedElement> {
		if let cache = caches[DownloadedElement.cacheKey] as? ElementCache<DownloadedElement> { return cache }
		
		let cache: LocalElementCache<DownloadedElement> = LocalElementCache()
		let wrapped = ElementCache(wrapped: cache)
		caches[DownloadedElement.cacheKey] = wrapped
		return wrapped
	}

}

fileprivate extension Decodable {
	static var cacheKey: String { String(describing: type(of: self)) }
}
