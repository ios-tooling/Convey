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
	
	public struct ImageInfo: Sendable {
		public let image: PlatformImage?
		public let localURL: URL?
		public let remoteURL: URL?
		
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

	public nonisolated func provision(url: URL, kind: DataCache.CacheKind = .default, suffix: String? = nil, ext: String? = nil) -> DataCache.Provision {
		DataCache.Provision(url: url, kind: kind, suffix: suffix, ext: ext, root: parentDirectory.value)
	}

	public func store(image: PlatformImage, for url: URL) async {
		if let data = image.data {
			try? await DataCache.instance.replace(data: data, for: provision(url: url, ext: "jpeg"))
		}
	}
	
	nonisolated func cacheCount() -> Int { inMemoryImages.value.count }
	public nonisolated func fetchLocal(for url: URL, kind: DataCache.CacheKind = .default, size: ImageSize? = nil, extension ext: String? = nil) -> PlatformImage? {
		fetchLocalInfo(for: url, kind: kind, size: size, extension: ext)?.image
	}

	public func removeItem(for url: URL) async {
		await removeItem(for: provision(url: url))
	}

	public func removeItem(for provision: DataCache.Provision) async {
		let key = provision.key
		await DataCache.instance.removeItem(for: provision)
		inMemoryImages.value.removeValue(forKey: key)
	}

	public nonisolated func fetchLocalImage(for url: URL?, kind: DataCache.CacheKind = .default, size: ImageSize? = nil, extension ext: String? = nil) -> PlatformImage? {
		fetchLocalInfo(for: url, kind: kind, size: size, extension: ext)?.image
	}
		
	public nonisolated func fetchLocalInfo(for url: URL?, kind: DataCache.CacheKind = .default, size: ImageSize? = nil, extension ext: String? = nil) -> ImageInfo? {
		guard let url else { return nil }
		return fetchLocalInfo(for: provision(url: url, kind: kind, suffix: size?.suffix, ext: ext), size: size)
	}

	public nonisolated func fetchLocalInfo(for prov: DataCache.Provision, size: ImageSize? = nil) -> ImageInfo? {
		let provision = prov.byAdding(extension: prov.ext ?? prov.url.cachePathExtension ?? "jpeg")
		let key = provision.key
		let localURL = provision.localURL
		let remoteURL = provision.url

		if let cached = inMemoryImages.value[key] { return .init(image: cached.image, localURL: localURL, remoteURL: remoteURL) }
		
		guard let data = DataCache.instance.fetchLocal(for: provision) else { return .init(image: nil, localURL: localURL, remoteURL: remoteURL) }
		
		#if os(iOS)
		if let url = data.url, let resized = url.resizedImage(maxWidth: size?.width, maxHeight: size?.height) {
				return .init(image: PlatformImage(cgImage: resized), localURL: localURL, remoteURL: remoteURL)
			}
		#endif
		
		if let image = PlatformImage(data: data.data) {
			let resized = size?.resize(image) ?? image
			updateCache(for: key, with: InMemoryImage(image: resized, size: data.data.count, createdAt: Date(), key: key, group: provision.group))
			return .init(image: resized, localURL: localURL, remoteURL: remoteURL)
		}
		return .init(image: nil, localURL: localURL, remoteURL: remoteURL)
	}

	public nonisolated func fetchLocalData(for url: URL, location: DataCache.CacheKind = .default, size: ImageSize? = nil) -> DataCache.DataAndLocalCache? {
		fetchLocalData(for: provision(url: url, kind: location), size: size)
	}

	public nonisolated func fetchLocalData(for provision: DataCache.Provision, size: ImageSize? = nil) -> DataCache.DataAndLocalCache? {
		DataCache.instance.fetchLocal(for: provision)
	}

	nonisolated public func hasCachedValue(for url: URL, kind: DataCache.CacheKind = .default, size: ImageSize? = nil, newerThan: Date? = nil) -> Bool {
		hasCachedValue(for: provision(url: url, kind: kind))
	}

	nonisolated public func hasCachedValue(for provision: DataCache.Provision, size: ImageSize? = nil, newerThan: Date? = nil) -> Bool {
		let key = provision.key
		if let _ = inMemoryImages.value[key] { return true }

		return DataCache.instance.hasCachedValue(for: provision, newerThan: newerThan)
	}
	
	nonisolated func updateCache(for key: String, with image: InMemoryImage) {
		var cache = inMemoryImages.value
		cache[key] = image
		inMemoryImages.send(cache)

	}

	nonisolated func location(for url: URL) -> DataCache.CacheKind {
		location(for: provision(url: url, ext: url.cachePathExtension))
	}
	
	nonisolated func location(for provision: DataCache.Provision) -> DataCache.CacheKind {
		let pathExtension = provision.ext ?? "jpeg"
		switch provision.kind {
		case .default:
			return .fixed(parentDirectory.value.appendingPathComponent(provision.url.cacheKey + "." + pathExtension))

		case .keyed(let key):
			return .fixed(parentDirectory.value.appendingPathComponent(key))
			
		case .fixed:
			return provision.kind
			
		case .grouped(let group, let key):
			return .fixed(parentDirectory.value.appendingPathComponent(group).appendingPathComponent(key ?? (provision.url.cacheKey + "." + pathExtension)))
		}
	}
	
	public func fetch(from provision: DataCache.Provision, caching: DataCache.Caching = .localFirst, size: ImageSize? = nil) async throws -> PlatformImage? {
		try await fetchInfo(using: SimpleGETTask(url: provision.url), caching: caching, kind: provision.kind, size: size).image
	}

	public func prune(location: DataCache.CacheKind) {
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
	struct InMemoryImage: Sendable {
		let image: PlatformImage
		let size: Int
		let createdAt: Date
		let key: String
		let group: String?
		
		var age: TimeInterval { abs(createdAt.timeIntervalSinceNow) }
	}
}
