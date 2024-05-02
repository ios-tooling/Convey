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
	let wrapped: CurrentValueSubject<any DownloadedElementCache<Element>, Never>
	
	var observer: AnyCancellable?
	
	init(wrapped: any DownloadedElementCache<Element>) {
		self.wrapped = .init(wrapped)
		Task { await setupWrapper() }
	}
	
	func setupWrapper() {
		observer = (self.wrapped.value.objectWillChange as? ObservableObjectPublisher)?
			.receive(on: RunLoop.main)
			.sink { _ in
				self.objectWillChange.send()
			}
	}
	
	public func load(items newItems: [Element]) { Task { await wrapped.value.load(items: items) }}
	public func refresh() async throws { try await wrapped.value.refresh() }
	public func refresh<NewDownloader: PayloadDownloadingTask>(from task: NewDownloader) async throws -> Void where NewDownloader.DownloadPayload: WrappedDownloadArray, NewDownloader.DownloadPayload.Element == Element {
		try await wrapped.value.refresh(from: task)
	}
	
	public nonisolated var items: [Element] { wrapped.value.items }
	public var cacheLocation: URL? { nil }
	public nonisolated func setup() { wrapped.value.setup() }
}

@available(iOS 16, macOS 13, watchOS 9, *)
public class DownloadedElementCacheManager {
	public static let instance = DownloadedElementCacheManager()
	
	var caches: [String: any DownloadedElementCache] = [:]
	
	func fetchCache<Downloader: PayloadDownloadingTask, DownloadedElement: CacheableElement>(_ downloader: Downloader, redirect: TaskRedirect? = nil) -> (ElementCache<DownloadedElement>) where Downloader.DownloadPayload: WrappedDownloadArray, Downloader.DownloadPayload.Element == DownloadedElement {
		if let cache = caches[DownloadedElement.cacheKey] as? ElementCache<DownloadedElement> {
			if cache.wrapped.value is (TaskBasedCodableArrayCache<Downloader, DownloadedElement>) { return cache }
			
			cache.wrapped.value = TaskBasedCodableArrayCache(updateTask: downloader, redirect: redirect)
			return cache
		}
		
		let cache = TaskBasedCodableArrayCache(updateTask: downloader, redirect: redirect)
		let wrapped = ElementCache(wrapped: cache)
		caches[DownloadedElement.cacheKey] = wrapped
		return wrapped
	}
	
	func fetchCache<DownloadedElement: CacheableElement>(redirect: TaskRedirect? = nil) -> ElementCache<DownloadedElement> {
		if let cache = caches[DownloadedElement.cacheKey] as? ElementCache<DownloadedElement> { return cache }
		
		let cache: CodableArrayCache<DownloadedElement> = CodableArrayCache(redirect: redirect)
		let wrapped = ElementCache(wrapped: cache)
		caches[DownloadedElement.cacheKey] = wrapped
		return wrapped
	}

}

fileprivate extension Decodable {
	static var cacheKey: String { String(describing: type(of: self)) }
}
