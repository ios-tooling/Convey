//
//  CacheableElement.swift
//  
//
//  Created by Ben Gottlieb on 5/2/24.
//

import Foundation

public typealias CacheableElement = Codable & Equatable & Sendable


@available(iOS 16, macOS 13, watchOS 9, *)
public extension Decodable where Self: CacheableElement {
	static var downloadedCache: DownloadedArrayCache<Self> { DownloadedCacheManager.instance.fetchCache() }
	static func downloadedCache(redirect: TaskRedirect? = nil, refresh: CacheRefreshTiming = .atStartup, update: (() async throws -> [Self])? = nil) -> DownloadedArrayCache<Self> { DownloadedCacheManager.instance.fetchCache(redirect: redirect, refresh: refresh, update: update) }
	static func downloadedCache<Downloader: PayloadDownloadingTask>(_ downloader: Downloader, redirect: TaskRedirect? = nil, refresh: CacheRefreshTiming = .atStartup) -> DownloadedArrayCache<Self> where Downloader.DownloadPayload: WrappedDownloadArray, Downloader.DownloadPayload.Element == Self { DownloadedCacheManager.instance.fetchCache(downloader, redirect: redirect, refresh: refresh) }
}
