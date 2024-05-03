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
	static var downloadedCache: ElementCache<Self> { DownloadedElementCacheManager.instance.fetchCache() }
	static func downloadedCache(redirect: TaskRedirect? = nil) -> ElementCache<Self> { DownloadedElementCacheManager.instance.fetchCache(redirect: redirect) }
	static func downloadedCache<Downloader: PayloadDownloadingTask>(_ downloader: Downloader, redirect: TaskRedirect? = nil) -> ElementCache<Self> where Downloader.DownloadPayload: WrappedDownloadArray, Downloader.DownloadPayload.Element == Self { DownloadedElementCacheManager.instance.fetchCache(downloader, redirect: redirect) }
}
