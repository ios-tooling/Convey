//
//  ImageCache.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 6/4/22.
//

import Combine

#if os(macOS)
	import Cocoa
#else
	import UIKit
#endif



public actor ImageCache {
	public static let instance = ImageCache()
	public var cachesDirectory = URL.systemDirectoryURL(which: .cachesDirectory)!.appendingPathComponent("images")
	
	nonisolated let inMemoryImages = CurrentValueSubject<[String: InMemoryImage], Never>([:])
	
	var currentSizeLimit: Int? = 1_000_000 * 100
	var totalSize: Int {
		inMemoryImages.value.values.map { $0.size }.reduce(0) { $0 + $1 }
	}

	public func setCacheRoot(_ root: URL) { cachesDirectory = root }
	public func setCacheLimit(_ limit: Int) { currentSizeLimit = limit }
	public func fetchTotalSize() -> Int { totalSize }
	public func fetch<FetchTask: ServerTask>(using task: FetchTask, caching: DataCache.Caching = .localFirst, location: DataCache.CacheLocation = .default, size: ImageSize? = nil) async throws -> PlatformImage? {
		
		let key = location.key(for: task.url)
		if let cachedImage = inMemoryImages.value[key]?.image {
            return cachedImage
        }
		
		guard let data = try await DataCache.instance.fetch(using: task, caching: caching, location: location) else { return nil }
		
		if let image = PlatformImage(data: data) {
			let resized = size?.resize(image) ?? image
			if resized != image, let data = resized.data {
				try? DataCache.instance.replace(data: data, for: task, location: location)
			}
			if caching == .never { return resized }
			updateCache(for: key, with: InMemoryImage(image: resized, size: data.count, createdAt: Date(), key: key, group: location.group))
			prune()
			return resized
		}
		return nil
	}
	
	nonisolated func cacheCount() -> Int { inMemoryImages.value.count }
	public nonisolated func fetchLocal(for url: URL, location: DataCache.CacheLocation = .default, size: ImageSize? = nil) -> PlatformImage? {
		let key = location.key(for: url)
		if let cached = inMemoryImages.value[key] { return cached.image }
		
		guard let data = DataCache.instance.fetchLocal(for: url, location: location) else { return nil }
		
		if let image = PlatformImage(data: data.data) {
			updateCache(for: key, with: InMemoryImage(image: image, size: data.data.count, createdAt: Date(), key: key, group: location.group))
			return image
		}
		return nil
	}
	
	nonisolated public func hasCachedValue(for url: URL, location: DataCache.CacheLocation = .default, newerThan: Date? = nil) -> Bool {
		let key = location.key(for: url)
		if let _ = inMemoryImages.value[key] { return true }

		return DataCache.instance.hasCachedValue(for: url, location: location, newerThan: newerThan)
	}
	
	nonisolated func updateCache(for key: String, with image: InMemoryImage) {
		var cache = inMemoryImages.value
		cache[key] = image
		inMemoryImages.send(cache)

	}
	
	public func fetch(from url: URL, caching: DataCache.Caching = .localFirst, location: DataCache.CacheLocation = .default, size: ImageSize? = nil) async throws -> PlatformImage? {
		try await fetch(using: SimpleGETTask(url: url), caching: caching, location: location, size: size)
	}

	public func prune(location: DataCache.CacheLocation) {
		var cache = inMemoryImages.value
		for image in inMemoryImages.value.values.filter({ $0.group == location.group }) {
			cache.removeValue(forKey: image.key)
		}
		inMemoryImages.send(cache)
	}
	
	public func prune(maxSize: Int? = nil, maxAge: TimeInterval? = nil) {
		var cache = inMemoryImages.value
		let all = cache.values.sorted { $0.createdAt > $1.createdAt }
		
		if let age = maxAge {
			for image in all {
				if image.age > age { cache.removeValue(forKey: image.key) }
			}
		} else if let size = maxSize ?? currentSizeLimit {
			var total = 0
			
			for image in all {
				if total > size { cache.removeValue(forKey: image.key) }
				total += image.size
			}
		}
		inMemoryImages.send(cache)
	}

}

extension ImageCache {
	struct InMemoryImage {
		let image: PlatformImage
		let size: Int
		let createdAt: Date
		let key: String
		let group: String?
		
		var age: TimeInterval { abs(createdAt.timeIntervalSinceNow) }
	}
}
