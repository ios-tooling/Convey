//
//  DownloadedElementCacheManager.swift
//
//
//  Created by Ben Gottlieb on 5/2/24.
//

import Foundation
import Combine

@available(iOS 16, macOS 13, watchOS 9, *)
public class DownloadedElementCacheManager {
	public static let instance = DownloadedElementCacheManager()
	
	var caches: [String: any CodableElementCacheProtocol] = [:]
	
	func fetchCache<Downloader: PayloadDownloadingTask, DownloadedElement: CacheableElement>(_ downloader: Downloader, redirect: TaskRedirect? = nil, refresh: CacheRefreshTiming = .atStartup) -> CodableElementCache<DownloadedElement> where Downloader.DownloadPayload: WrappedDownloadArray, Downloader.DownloadPayload.Element == DownloadedElement {
		if let cache = caches[DownloadedElement.cacheKey] as? CodableElementCache<DownloadedElement> {
			Task { await cache.updateRefreshClosure(for: downloader, redirects: redirect) }
			return cache
		}
		
		let cache = CodableElementCache(downloader: downloader, redirect: redirect, refresh: refresh)
		caches[DownloadedElement.cacheKey] = cache
		return cache
	}
	
	func fetchCache<DownloadedElement: CacheableElement>(redirect: TaskRedirect? = nil, refresh: CacheRefreshTiming = .atStartup, update: (() async throws -> [DownloadedElement])? = nil) -> (CodableElementCache<DownloadedElement>) {
		if let cache = caches[DownloadedElement.cacheKey] as? CodableElementCache<DownloadedElement> {
			return cache
		}
		
		let cache = CodableElementCache(redirect: redirect, refresh: refresh, update: update)
		caches[DownloadedElement.cacheKey] = cache
		return cache
	}

}

fileprivate extension Decodable {
	static var cacheKey: String { String(describing: type(of: self)) }
}
