//
//  DownloadedElementCacheManager.swift
//
//
//  Created by Ben Gottlieb on 5/2/24.
//

import Foundation
import Combine

@available(iOS 16, macOS 13, watchOS 9, *)
public class DownloadedCacheManager {
	public static let instance = DownloadedCacheManager()
	
	var caches: [String: any DownloadedCacheProtocol] = [:]
	
	func fetchCache<DownloadedElement: CacheableContent>(redirect: TaskRedirect? = nil, refresh: CacheRefreshTiming = .atStartup, update: (() async throws -> DownloadedElement)? = nil) -> (DownloadedCache<DownloadedElement>) {
		if let cache = caches[DownloadedElement.cacheKey] as? DownloadedCache<DownloadedElement> {
			return cache
		}
		
		let cache = DownloadedCache(redirect: redirect, refresh: refresh, update: update)
		caches[DownloadedElement.cacheKey] = cache
		return cache
	}

	func fetchCache<Downloader: PayloadDownloadingTask, DownloadedElement: CacheableContent>(_ downloader: Downloader, redirect: TaskRedirect? = nil, refresh: CacheRefreshTiming = .atStartup) -> DownloadedCache<DownloadedElement> where Downloader.DownloadPayload == DownloadedElement {
		if let cache = caches[DownloadedElement.cacheKey] as? DownloadedCache<DownloadedElement> {
			Task { await cache.updateRefreshClosure(for: downloader, redirects: redirect) }
			return cache
		}
		
		let cache = DownloadedCache(downloader: downloader, redirect: redirect, refresh: refresh)
		caches[DownloadedElement.cacheKey] = cache
		return cache
	}
	
	func fetchArrayCache<Downloader: PayloadDownloadingTask, DownloadedElement: CacheableContent>(_ downloader: Downloader, redirect: TaskRedirect? = nil, refresh: CacheRefreshTiming = .atStartup) -> DownloadedArrayCache<DownloadedElement> where Downloader.DownloadPayload: WrappedDownloadArray, Downloader.DownloadPayload.Element == DownloadedElement {
		if let cache = caches[DownloadedElement.cacheKey] as? DownloadedArrayCache<DownloadedElement> {
			Task { await cache.updateRefreshClosure(for: downloader, redirects: redirect) }
			return cache
		}
		
		let cache = DownloadedArrayCache(downloader: downloader, redirect: redirect, refresh: refresh)
		caches[DownloadedElement.cacheKey] = cache
		return cache
	}
	
	func fetchArrayCache<DownloadedElement: CacheableContent>(redirect: TaskRedirect? = nil, refresh: CacheRefreshTiming = .atStartup, update: (() async throws -> [DownloadedElement])? = nil) -> (DownloadedArrayCache<DownloadedElement>) {
		if let cache = caches[DownloadedElement.cacheKey] as? DownloadedArrayCache<DownloadedElement> {
			return cache
		}
		
		let cache = DownloadedArrayCache(redirect: redirect, refresh: refresh, update: update)
		caches[DownloadedElement.cacheKey] = cache
		return cache
	}

}

fileprivate extension Decodable {
	static var cacheKey: String { String(describing: type(of: self)) }
}
