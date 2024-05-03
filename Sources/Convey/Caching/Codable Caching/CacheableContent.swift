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
	static var downloadedArrayCache: DownloadedArrayCache<Self> { DownloadedCacheManager.instance.fetchArrayCache() }
	
	static func downloadedCache(redirect: TaskRedirect? = nil, refresh: CacheRefreshTiming = .atStartup, update: (() async throws -> Self)? = nil) -> DownloadedCache<Self> { DownloadedCacheManager.instance.fetchCache(redirect: redirect, refresh: refresh, update: update) }

	static func downloadedCache<Downloader: PayloadDownloadingTask>(_ downloader: Downloader, redirect: TaskRedirect? = nil, refresh: CacheRefreshTiming = .atStartup) -> DownloadedCache<Self> where Downloader.DownloadPayload == Self { DownloadedCacheManager.instance.fetchCache(downloader, redirect: redirect, refresh: refresh) }

	static func downloadedArrayCache(redirect: TaskRedirect? = nil, refresh: CacheRefreshTiming = .atStartup, update: (() async throws -> [Self])? = nil) -> DownloadedArrayCache<Self> { DownloadedCacheManager.instance.fetchArrayCache(redirect: redirect, refresh: refresh, update: update) }

	static func downloadedArrayCache<Downloader: PayloadDownloadingTask>(_ downloader: Downloader, redirect: TaskRedirect? = nil, refresh: CacheRefreshTiming = .atStartup) -> DownloadedArrayCache<Self> where Downloader.DownloadPayload: WrappedDownloadArray, Downloader.DownloadPayload.Element == Self { DownloadedCacheManager.instance.fetchArrayCache(downloader, redirect: redirect, refresh: refresh) }
}
