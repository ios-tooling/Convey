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
	
	func fetchCache<DownloadedElement: CacheableContent>(name: String? = nil, redirect: TaskRedirect? = nil, refresh: CacheRefreshTiming = .atStartup, update: (() async throws -> DownloadedElement?)? = nil) -> (DownloadCache<DownloadedElement>) {
		
		let key = name ?? DownloadedElement.cacheKey
		if let cache = caches[key] as? DownloadCache<DownloadedElement> {
			return cache
		}
		
		let cache = DownloadCache(cacheName: name, redirect: redirect, refresh: refresh, update: update)
		caches[key] = cache
		return cache
	}

	func fetchCache<Downloader: PayloadDownloadingTask, DownloadedElement: CacheableContent>(_ downloader: Downloader, name: String? = nil, redirect: TaskRedirect? = nil, refresh: CacheRefreshTiming = .atStartup) -> DownloadCache<DownloadedElement> where Downloader.DownloadPayload == DownloadedElement {
		let key = name ?? DownloadedElement.cacheKey
		if let cache = caches[key] as? DownloadCache<DownloadedElement> {
			Task { await cache.updateRefreshClosure(for: downloader, redirects: redirect) }
			return cache
		}
		
		let cache = DownloadCache(downloader: downloader, cacheName: name, redirect: redirect, refresh: refresh)
		caches[key] = cache
		return cache
	}
	
	func fetchCache<Downloader: PayloadDownloadingTask, DownloadedElement: CacheableContent>(_ downloader: Downloader, name: String? = nil, redirect: TaskRedirect? = nil, refresh: CacheRefreshTiming = .atStartup) -> DownloadCache<DownloadedElement> where Downloader.DownloadPayload: WrappedDownloadItem, Downloader.DownloadPayload.WrappedItem == DownloadedElement {
		let key = name ?? DownloadedElement.cacheKey
		if let cache = caches[key] as? DownloadCache<DownloadedElement> {
			Task { await cache.updateRefreshClosure(for: downloader, redirects: redirect) }
			return cache
		}
		
		let cache = DownloadCache(wrappedDownloader: downloader, cacheName: name, redirect: redirect, refresh: refresh)
		caches[key] = cache
		return cache
	}
	
	func fetchArrayCache<Downloader: PayloadDownloadingTask, DownloadedElement: CacheableContent>(_ downloader: Downloader, name: String? = nil, redirect: TaskRedirect? = nil, refresh: CacheRefreshTiming = .atStartup) -> DownloadArrayCache<DownloadedElement> where Downloader.DownloadPayload: WrappedDownloadArray, Downloader.DownloadPayload.Element == DownloadedElement {
		let key = name ?? DownloadedElement.cacheKey
		if let cache = caches[key] as? DownloadArrayCache<DownloadedElement> {
			Task { await cache.updateRefreshClosure(for: downloader, redirects: redirect) }
			return cache
		}
		
		let cache = DownloadArrayCache(downloader: downloader, cacheName: name, redirect: redirect, refresh: refresh)
		caches[key] = cache
		return cache
	}
	
	func fetchArrayCache<DownloadedElement: CacheableContent>(name: String? = nil, redirect: TaskRedirect? = nil, refresh: CacheRefreshTiming = .atStartup, update: (() async throws -> [DownloadedElement]?)? = nil) -> (DownloadArrayCache<DownloadedElement>) {
		let key = name ?? DownloadedElement.cacheKey
		if let cache = caches[key] as? DownloadArrayCache<DownloadedElement> {
			return cache
		}
		
		let cache = DownloadArrayCache(cacheName: name, redirect: redirect, refresh: refresh, update: update)
		caches[key] = cache
		return cache
	}

}

fileprivate extension Decodable {
	static var cacheKey: String { String(describing: type(of: self)) }
}
