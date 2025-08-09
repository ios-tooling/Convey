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
		parentDirectory.set(cachesDirectory)
	}}
	
	nonisolated let inMemoryImages = ConveyThreadsafeMutex<[String: InMemoryImage]>([:])
	nonisolated let parentDirectory = ConveyThreadsafeMutex<URL>(ImageCache.defaultDirectory)
	
	public struct ImageInfo: Sendable {
		public let image: PlatformImage?
		public let localURL: URL?
		public let remoteURL: URL?
		
		static let empty = ImageInfo(image: nil, localURL: nil, remoteURL: nil)
	}

	static nonisolated let defaultDirectory = URL.systemDirectoryURL(which: .cachesDirectory)!.appendingPathComponent("images")
	var currentSizeLimit: Int? = 1_000_000 * 100
	var totalSize: Int {
		inMemoryImages.value.values.map { $0.size }.reduce(0) { $0 + $1 }
	}

	public func clear(inMemory: Bool, onDisk: Bool) {
		if inMemory { inMemoryImages.set([:]) }
		if onDisk {
			// we're going to ignore any errors here. If we can't clear the data, not much we can do
			try? FileManager.default.removeItemIfExists(at: parentDirectory.value)
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
			do {
				try await DataCache.instance.replace(data: data, for: provision(url: url, ext: "jpeg"))
			} catch {
				print("Failed to store \(data.count) bytes at \(url.path): \(error)")
			}
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
		inMemoryImages.perform {
			$0.removeValue(forKey: key)
		}
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
			Task {
				await updateCache(for: key, with: InMemoryImage(image: resized, size: data.data.count, createdAt: Date(), key: key, group: provision.group))
			}
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
	
	func updateCache(for key: String, with image: InMemoryImage) {
		inMemoryImages.perform { $0[key] = image }
	}
	
	public func fetch(from provision: DataCache.Provision, caching: DataCache.Caching = .localFirst, size: ImageSize? = nil) async throws -> PlatformImage? {
		try await fetchInfo(using: GetImageTask(url: provision.url), caching: caching, kind: provision.kind, size: size).image
	}
	
	public func fetch(from url: URL, kind: DataCache.CacheKind = .default, caching: DataCache.Caching = .localFirst, size: ImageSize? = nil) async throws -> PlatformImage? {
		try await fetchInfo(using: GetImageTask(url: url), caching: caching, kind: .default, size: size).image
	}

	public func prune(location: DataCache.CacheKind) {
		inMemoryImages.perform { images in
			for image in images.values.filter({ $0.group == location.group }) {
				images.removeValue(forKey: image.key)
			}
		}
	}
	
	public func prune(maxSize: Int? = nil, maxAge: TimeInterval? = nil) {
		inMemoryImages.perform { cache in
			let all = cache.values.sorted { $0.createdAt > $1.createdAt }
			
			if let age = maxAge {
				for image in all {
					if image.age > age { cache.removeValue(forKey: image.key) }
				}
			} else if let size = maxSize ?? currentSizeLimit {
				var total = 0
				
				for image in all {
					if total + image.size > size {
						cache.removeValue(forKey: image.key)
					} else {
						total += image.size
					}
				}
			}
		}
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
