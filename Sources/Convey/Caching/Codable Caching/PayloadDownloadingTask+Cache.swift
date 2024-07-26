//
//  PayloadDownloadingTask+Cache.swift
//
//
//  Created by Ben Gottlieb on 5/4/24.
//

import Foundation

@available(iOS 16, macOS 13, watchOS 9, *)
public extension PayloadDownloadingTask where DownloadPayload: CacheableContent {
	static var downloadedCache: DownloadCache<DownloadPayload> { DownloadedCacheManager.instance.fetchCache() }

	var downloadedCache: DownloadCache<DownloadPayload> { DownloadedCacheManager.instance.fetchCache(self) }

	func downloadedCache(name: String? = nil, redirect: TaskRedirect? = nil, refresh: CacheRefreshTiming = .atStartup) -> DownloadCache<DownloadPayload> {
		DownloadedCacheManager.instance.fetchCache(self, name: name, redirect: redirect, refresh: refresh)
	}
}

@available(iOS 16, macOS 13, watchOS 9, *)
public extension PayloadDownloadingTask where DownloadPayload: WrappedDownloadArray & Encodable, DownloadPayload.Element: CacheableContent {
	static var downloadedArrayCache: DownloadArrayCache<DownloadPayload.Element> { DownloadedCacheManager.instance.fetchArrayCache() }
	
	var downloadedArrayCache: DownloadArrayCache<DownloadPayload.Element> { DownloadedCacheManager.instance.fetchArrayCache(self) }

	func downloadedArrayCache(name: String? = nil, redirect: TaskRedirect? = nil, refresh: CacheRefreshTiming = .atStartup) -> DownloadArrayCache<DownloadPayload.Element> {
		DownloadedCacheManager.instance.fetchArrayCache(self, name: name, redirect: redirect, refresh: refresh)
	}

}
