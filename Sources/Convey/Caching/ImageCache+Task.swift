//
//  ImageCache+Task.swift
//  PGRGuide
//
//  Created by Ben Gottlieb on 7/2/23.
//

import Combine
#if os(macOS)
	import Cocoa
#else
	import UIKit
#endif

extension ImageCache {
	public func fetch<FetchTask: ServerTask>(using task: FetchTask, caching: DataCache.Caching = .localFirst, kind: DataCache.CacheKind = .default, size: ImageSize? = nil) async throws -> PlatformImage? {
		try await fetchInfo(using: task, caching: caching, kind: kind, size: size).image
	}

	public func fetchInfo<FetchTask: ServerTask>(using task: FetchTask, caching: DataCache.Caching = .localFirst, kind: DataCache.CacheKind = .default, size: ImageSize? = nil) async throws -> ImageInfo {
		let provision = provision(url: task.url, kind: kind, suffix: size?.suffix, ext: task.url.cachePathExtension ?? "jpeg")
		let key = provision.key
		let localURL = provision.localURL
		
		if let cachedImage = inMemoryImages.value[key]?.image {
			return .init(image: cachedImage, localURL: localURL, remoteURL: task.url)
		}
		guard let data = try await DataCache.instance.fetch(using: task, caching: caching, provision: provision.byRemovingSuffix()) else { return .init(image: nil, localURL: localURL, remoteURL: task.url) }
		
		if let image = PlatformImage(data: data) {
			let resized = size?.resize(image) ?? image
			if resized != image, let data = resized.jpegData(compressionQuality: 0.9) {
				try? DataCache.instance.replace(data: data, for: task, provision: provision)
			}
			if caching == .never { return .init(image: resized, localURL: localURL, remoteURL: task.url) }
			updateCache(for: key, with: InMemoryImage(image: resized, size: data.count, createdAt: Date(), key: key, group: provision.group))
			prune()
			return .init(image: resized, localURL: localURL, remoteURL: task.url)
		}
		return .init(image: nil, localURL: localURL, remoteURL: task.url)
	}
	

}
