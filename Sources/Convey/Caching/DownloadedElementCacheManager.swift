//
//  DownloadedElementCacheManager.swift
//
//
//  Created by Ben Gottlieb on 5/2/24.
//

import Foundation

@available(iOS 16, macOS 13, watchOS 9, *)
public extension Decodable where Self: CacheableElement {
	static var downloadElementCache: (any DownloadedElementCache<Self>) { DownloadedElementCacheManager.instance.fetchCache() }
	static func downloadElementCache<Downloader: PayloadDownloadingTask>(_ downloader: Downloader) -> (any DownloadedElementCache<Self>) where Downloader.DownloadPayload: WrappedDownloadArray, Downloader.DownloadPayload.Element == Self { DownloadedElementCacheManager.instance.fetchCache(downloader) }
}

@available(iOS 16, macOS 13, watchOS 9, *)
public class DownloadedElementCacheManager {
	public static let instance = DownloadedElementCacheManager()
	
	var caches: [String: any DownloadedElementCache] = [:]
	
	func fetchCache<Downloader: PayloadDownloadingTask, DownloadedElement: CacheableElement>(_ downloader: Downloader) -> (any DownloadedElementCache<DownloadedElement>) where Downloader.DownloadPayload: WrappedDownloadArray, Downloader.DownloadPayload.Element == DownloadedElement {
		if let cache = caches[DownloadedElement.cacheKey] as? (any DownloadedElementCache<DownloadedElement>) { return cache }
		
		let cache = PayloadDownloadedElementCache(updateTask: downloader)
		
		caches[DownloadedElement.cacheKey] = cache
		return cache
	}
	
	func fetchCache<DownloadedElement: CacheableElement>() -> (any DownloadedElementCache<DownloadedElement>) {
		if let cache = caches[DownloadedElement.cacheKey] as? (any DownloadedElementCache<DownloadedElement>) { return cache }
		
		let cache: LocalElementCache<DownloadedElement> = LocalElementCache()
		
		caches[DownloadedElement.cacheKey] = cache
		return cache
	}

}

fileprivate extension Decodable {
	static var cacheKey: String { String(describing: type(of: self)) }
}
