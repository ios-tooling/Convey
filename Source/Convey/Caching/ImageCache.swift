//
//  ImageCache.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 6/4/22.
//

#if os(macOS)
	import Cocoa

	public typealias PlatformImage = NSImage
#else
	import UIKit

	public typealias PlatformImage = UIImage
#endif

public actor ImageCache {
	public static let instance = ImageCache()
	public var cachesDirectory = URL.systemDirectoryURL(which: .cachesDirectory)!.appendingPathComponent("images")
	
	var inMemoryImages: [String: InMemoryImage] = [:]
	var currentSizeLimit: Int? = 1_000_000 * 100
	var totalSize: Int { inMemoryImages.values.map { $0.size }.sum() }

	public func setCacheLimit(_ limit: Int) { currentSizeLimit = limit }
	public func fetchTotalSize() -> Int { totalSize }
	public func fetch<FetchTask: ServerTask>(using task: FetchTask, caching: DataCache.Caching = .localFirst, location: DataCache.CacheLocation = .default) async throws -> PlatformImage? {
		
		let key = location.key(for: task.url)
		if let cached = inMemoryImages[key] { return cached.image }
		
		guard let data = try await DataCache.instance.fetch(using: task, caching: caching, location: location) else { return nil }
		
		if let image = PlatformImage(data: data) {
			if caching == .never { return image }
			inMemoryImages[key] = InMemoryImage(image: image, size: data.count, createdAt: Date(), key: key)
			
			prune()
			return image
		}
		return nil
	}
	
	public func fetch(from url: URL, caching: DataCache.Caching = .localFirst, location: DataCache.CacheLocation = .default) async throws -> PlatformImage? {
		try await fetch(using: SimpleGETTask(url: url), caching: caching, location: location)
	}

	public func prune(maxSize: Int? = nil, maxAge: TimeInterval? = nil) {
		let all = inMemoryImages.values.sorted { $0.createdAt > $1.createdAt }
		
		if let age = maxAge {
			for image in all {
				if image.age > age { inMemoryImages.removeValue(forKey: image.key) }
			}
		} else if let size = maxSize ?? currentSizeLimit {
			var total = 0
			
			for image in all {
				if total > size { inMemoryImages.removeValue(forKey: image.key) }
				total += image.size
			}
		}
	}

}

extension ImageCache {
	struct InMemoryImage {
		let image: PlatformImage
		let size: Int
		let createdAt: Date
		let key: String
		
		var age: TimeInterval { abs(createdAt.timeIntervalSinceNow) }
	}
}
