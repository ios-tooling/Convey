//
//  CacheableElement.swift
//  
//
//  Created by Ben Gottlieb on 5/2/24.
//

import Foundation

public typealias CacheableContent = Codable & Equatable & Sendable


@available(iOS 16, macOS 13, watchOS 9, *)
public extension Decodable where Self: CacheableContent {
	static var downloadedCache: DownloadCache<Self> { DownloadedCacheManager.instance.fetchCache() }

	static func downloadedCache(name: String? = nil, redirect: TaskRedirect? = nil, refresh: CacheRefreshTiming = .atStartup, update: (() async throws -> Self?)? = nil) -> DownloadCache<Self> { DownloadedCacheManager.instance.fetchCache(name: name, redirect: redirect, refresh: refresh, update: update) }

	static func downloadedCache<Downloader: PayloadDownloadingTask>(_ downloader: Downloader, name: String? = nil, redirect: TaskRedirect? = nil, refresh: CacheRefreshTiming = .atStartup) -> DownloadCache<Self> where Downloader.DownloadPayload == Self { DownloadedCacheManager.instance.fetchCache(downloader, name: name, redirect: redirect, refresh: refresh) }
	
	static func downloadedCache<Downloader: PayloadDownloadingTask>(_ downloader: Downloader, name: String? = nil, redirect: TaskRedirect? = nil, refresh: CacheRefreshTiming = .atStartup) -> DownloadCache<Self> where Downloader.DownloadPayload: WrappedDownloadItem, Downloader.DownloadPayload.WrappedItem == Self { DownloadedCacheManager.instance.fetchCache(downloader, name: name, redirect: redirect, refresh: refresh) }
	
	
	static var downloadedArrayCache: DownloadArrayCache<Self> { DownloadedCacheManager.instance.fetchArrayCache() }
	
	static func downloadedArrayCache(name: String? = nil, redirect: TaskRedirect? = nil, refresh: CacheRefreshTiming = .atStartup, update: (() async throws -> [Self]?)? = nil) -> DownloadArrayCache<Self> { DownloadedCacheManager.instance.fetchArrayCache(name: name, redirect: redirect, refresh: refresh, update: update) }

	static func downloadedArrayCache<Downloader: PayloadDownloadingTask>(_ downloader: Downloader, name: String? = nil, redirect: TaskRedirect? = nil, refresh: CacheRefreshTiming = .atStartup) -> DownloadArrayCache<Self> where Downloader.DownloadPayload: WrappedDownloadArray, Downloader.DownloadPayload.Element == Self { DownloadedCacheManager.instance.fetchArrayCache(downloader, name: name, redirect: redirect, refresh: refresh) }
}
