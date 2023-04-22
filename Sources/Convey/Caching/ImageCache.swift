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
	public var cachesDirectory = ImageCache.defaultDirectory { didSet {
		parentDirectory.send(cachesDirectory)
	}}
	
	nonisolated let inMemoryImages = CurrentValueSubject<[String: InMemoryImage], Never>([:])
	nonisolated let parentDirectory = CurrentValueSubject<URL, Never>(ImageCache.defaultDirectory)
	
	public struct ImageInfo {
		let image: PlatformImage?
		let localURL: URL?
		let remoteURL: URL?
		
		static let empty = ImageInfo(image: nil, localURL: nil, remoteURL: nil)
	}

	static let defaultDirectory = URL.systemDirectoryURL(which: .cachesDirectory)!.appendingPathComponent("images")
	var currentSizeLimit: Int? = 1_000_000 * 100
	var totalSize: Int {
		inMemoryImages.value.values.map { $0.size }.reduce(0) { $0 + $1 }
	}

	public func clear(inMemory: Bool, onDisk: Bool) {
		if inMemory { inMemoryImages.value = [:] }
		if onDisk {
			try? FileManager.default.removeItem(at: parentDirectory.value)
			try? FileManager.default.createDirectory(at: parentDirectory.value, withIntermediateDirectories: true)
		}
	}

	public func setCacheRoot(_ root: URL) { cachesDirectory = root }
	public func setCacheLimit(_ limit: Int) { currentSizeLimit = limit }
	public func fetchTotalSize() -> Int { totalSize }

	public func fetch<FetchTask: ServerTask>(using task: FetchTask, caching: DataCache.Caching = .localFirst, location: DataCache.CacheLocation = .default, size: ImageSize? = nil) async throws -> PlatformImage? {
		try await fetchInfo(using: task, caching: caching, location: location, size: size).image
	}

	public func fetchInfo<FetchTask: ServerTask>(using task: FetchTask, caching: DataCache.Caching = .localFirst, location: DataCache.CacheLocation = .default, size: ImageSize? = nil) async throws -> ImageInfo {
		
		let key = location.key(for: task.url, suffix: size?.suffix, extension: task.url.cachePathExtension ?? "jpeg")
		let actualLocation = self.location(for: task.url, current: location)
		let localURL = DataCache.instance.location(of: task.url, relativeTo: actualLocation)
		
		if let cachedImage = inMemoryImages.value[key]?.image {
			return .init(image: cachedImage, localURL: localURL, remoteURL: task.url)
		}
		
		guard let data = try await DataCache.instance.fetch(using: task, caching: caching, location: actualLocation) else { return .init(image: nil, localURL: localURL, remoteURL: task.url) }
		
		if let image = PlatformImage(data: data) {
			let resized = size?.resize(image) ?? image
			if resized != image, let data = resized.data {
				try? DataCache.instance.replace(data: data, for: task, location: actualLocation)
			}
			if caching == .never { return .init(image: resized, localURL: localURL, remoteURL: task.url) }
			updateCache(for: key, with: InMemoryImage(image: resized, size: data.count, createdAt: Date(), key: key, group: location.group))
			prune()
			return .init(image: resized, localURL: localURL, remoteURL: task.url)
		}
		return .init(image: nil, localURL: localURL, remoteURL: task.url)
	}
	
	public func store(image: PlatformImage, for url: URL) {
		if let data = image.data {
			let location = self.location(for: url, current: .default, extension: "jpeg")
			try? DataCache.instance.replace(data: data, for: url, location: location, extension: "jpeg")
		}
	}
	
	nonisolated func cacheCount() -> Int { inMemoryImages.value.count }
	public nonisolated func fetchLocal(for url: URL, location: DataCache.CacheLocation = .default, size: ImageSize? = nil, extension ext: String? = nil) -> PlatformImage? {
		fetchLocalInfo(for: url, location: location, size: size, extension: ext)?.image
	}
	
	public func removeItem(for url: URL, location: DataCache.CacheLocation = .default) {
		let key = location.key(for: url, suffix: nil, extension: url.cachePathExtension ?? "jpeg")
		DataCache.instance.removeItem(for: url, location: location)
		inMemoryImages.value.removeValue(forKey: key)
	}

	public nonisolated func fetchLocalInfo(for url: URL?, location: DataCache.CacheLocation = .default, size: ImageSize? = nil, extension ext: String? = nil) -> ImageInfo? {
		guard let url else { return nil }
		let cacheExtension = ext ?? url.cachePathExtension ?? "jpeg"
		let key = location.key(for: url, suffix: size?.suffix, extension: cacheExtension)
		let actualLocation = self.location(for: url, current: location, extension: cacheExtension)
		let localURL = DataCache.instance.location(of: url, relativeTo: actualLocation)
		let remoteURL = url

		if let cached = inMemoryImages.value[key] { return .init(image: cached.image, localURL: localURL, remoteURL: remoteURL) }
		
		guard let data = DataCache.instance.fetchLocal(for: url, location: actualLocation) else { return .init(image: nil, localURL: localURL, remoteURL: remoteURL) }
		
		#if os(iOS)
		if let url = data.url, let resized = url.resizedImage(maxWidth: size?.width, maxHeight: size?.height) {
				return .init(image: PlatformImage(cgImage: resized), localURL: localURL, remoteURL: remoteURL)
			}
		#endif
		
		if let image = PlatformImage(data: data.data) {
			let resized = size?.resize(image) ?? image
			updateCache(for: key, with: InMemoryImage(image: resized, size: data.data.count, createdAt: Date(), key: key, group: location.group))
			return .init(image: resized, localURL: localURL, remoteURL: remoteURL)
		}
		return .init(image: nil, localURL: localURL, remoteURL: remoteURL)
	}
	
	public nonisolated func fetchLocalData(for url: URL, location: DataCache.CacheLocation = .default, size: ImageSize? = nil) -> DataCache.DataAndLocalCache? {
		let actualLocation = self.location(for: url, current: location)
		return DataCache.instance.fetchLocal(for: url, location: actualLocation)
	}
	
	nonisolated public func hasCachedValue(for url: URL, location: DataCache.CacheLocation = .default, size: ImageSize? = nil, newerThan: Date? = nil) -> Bool {
		let key = location.key(for: url, suffix: size?.suffix, extension: url.cachePathExtension ?? "jpeg")
		if let _ = inMemoryImages.value[key] { return true }

		let actualLocation = self.location(for: url, current: location)
		return DataCache.instance.hasCachedValue(for: url, location: actualLocation, newerThan: newerThan)
	}
	
	nonisolated func updateCache(for key: String, with image: InMemoryImage) {
		var cache = inMemoryImages.value
		cache[key] = image
		inMemoryImages.send(cache)

	}
	
	nonisolated func location(for url: URL, current: DataCache.CacheLocation, extension ext: String? = nil) -> DataCache.CacheLocation {
		let pathExtension = ext ?? url.cachePathExtension ?? "jpeg"
		switch current {
		case .default:
			return .fixed(parentDirectory.value.appendingPathComponent(url.cacheKey + "." + pathExtension))

		case .keyed(let key):
			return .fixed(parentDirectory.value.appendingPathComponent(key))
			
		case .fixed:
			return current
			
		case .grouped(let group, let key):
			return .fixed(parentDirectory.value.appendingPathComponent(group).appendingPathComponent(key ?? (url.cacheKey + "." + pathExtension)))
		}
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
