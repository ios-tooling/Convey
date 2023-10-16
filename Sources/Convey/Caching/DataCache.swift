//
//  DataCache.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 6/4/22.
//

import Foundation

public class DataCache {
	public static let instance = DataCache()
	public var cachesDirectory = URL.systemDirectoryURL(which: .cachesDirectory)!

	public func setCacheRoot(_ root: URL) { cachesDirectory = root }

	public func fetch(from url: URL? = nil, caching: Caching = .localFirst, provision: Provision? = nil) async throws -> Data? {
		guard provision != nil || url != nil else { return nil }
		return try await fetch(using: provision ?? self.provision(url: url!), caching: caching)
	}
	
	public func fetch(using provision: Provision, caching: Caching = .localFirst) async throws -> Data? {
		if provision.url.isFileURL { return try Data(contentsOf: provision.url) }
		return try await fetch(using: SimpleGETTask(url: provision.url), caching: caching, provision: provision)
	}

	public func fetchCachedLocation(from provision: Provision, caching: Caching = .localFirst) async throws -> URL? {
		try await fetchCachedLocation(using: SimpleGETTask(url: provision.url), caching: caching, provision: provision)
	}
	
	public func clear() {
		try? FileManager.default.removeItem(at: cachesDirectory)
		try? FileManager.default.createDirectory(at: cachesDirectory, withIntermediateDirectories: true)
	}
	
	public func prune(kind: CacheKind) {
		if let url = kind.container(relativeTo: cachesDirectory) {
			try? FileManager.default.removeItem(at: url)
		}
	}

	public func removeItem(for url: URL) {
		removeItem(for: provision(url: url, kind: .default))
	}
	
	public func removeItem(for provision: Provision) {
		try? FileManager.default.removeItem(at: provision.localURL)
	}

	@discardableResult func cache(data: Data, for url: URL) -> URL {
		cache(data: data, for: provision(url: url))
	}

	@discardableResult func cache(data: Data, for provision: Provision) -> URL {
		let localURL = provision.localURL //location.location(of: task.url, relativeTo: cachesDirectory)
		try? FileManager.default.createDirectory(at: localURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
		try? data.write(to: localURL)
		return localURL
	}
	
	public func location(of url: URL) -> URL {
		provision(url: url).localURL
	}

	public func replace(data: Data, for url: URL) throws {
		try replace(data: data, for: provision(url: url))
	}

	public func replace(data: Data, for provision: Provision) throws {
		let localURL = provision.localURL
		try? FileManager.default.removeItem(at: localURL)
		try? FileManager.default.createDirectory(at: localURL.deletingLastPathComponent(), withIntermediateDirectories: true)
		try data.write(to: localURL)
	}

	public func hasCachedValue(for url: URL, newerThan: Date? = nil) -> Bool {
		hasCachedValue(for: provision(url: url))
	}

	public func hasCachedValue(for provision: Provision, newerThan: Date? = nil) -> Bool {
		let localURL = provision.localURL
		
		if !FileManager.default.fileExists(atPath: localURL.path) { return false }
		guard let size = localURL.size, size > 0 else { return false }
		if let limit = newerThan {
			guard let date = localURL.creationDate, date > limit else { return false }
		}
		return true
	}

	public func fetchLocal(for url: URL, newerThan: Date? = nil) -> DataAndLocalCache? {
		fetchLocal(for: provision(url: url))
	}
		
	public func fetchLocal(for provision: Provision, newerThan: Date? = nil) -> DataAndLocalCache? {
		if provision.isLocal {
			if let data = try? Data(contentsOf: provision.localURL) {
				return DataAndLocalCache(data: data, url: provision.url)
			}
			return nil
		}
		let localURL = provision.localURL

		if !FileManager.default.fileExists(atPath: localURL.path) { return nil }
		if let limit = newerThan {
			guard let date = localURL.creationDate, date > limit else { return nil}
		}
		
		guard let data = try? Data(contentsOf: localURL) else { return nil }
		return DataAndLocalCache(data: data, url: localURL)
	}
	
	public struct DataAndLocalCache {
		public let data: Data
		public let url: URL?
	}
}

