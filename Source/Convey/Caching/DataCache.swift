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

	public func fetch<FetchTask: ServerTask>(using task: FetchTask, caching: Caching = .localFirst, location: CacheLocation = .default) async throws -> Data? {
		try await fetchDataAndCache(using: task, caching: caching, location: location)?.data
	}

	public func fetchCachedLocation<FetchTask: ServerTask>(using task: FetchTask, caching: Caching = .localFirst, location: CacheLocation = .default) async throws -> URL? {
		try await fetchDataAndCache(using: task, caching: caching, location: location)?.url
	}

	public func fetch(from url: URL, caching: Caching = .localFirst, location: CacheLocation = .default) async throws -> Data? {
		try await fetch(using: SimpleGETTask(url: url), caching: caching, location: location)
	}

	public func fetchCachedLocation(from url: URL, caching: Caching = .localFirst, location: CacheLocation = .default) async throws -> URL? {
		try await fetchCachedLocation(using: SimpleGETTask(url: url), caching: caching, location: location)
	}
	
	public func prune(location: CacheLocation) {
		if let url = location.container(relativeTo: cachesDirectory) {
			try? FileManager.default.removeItem(at: url)
		}
	}

	func fetchDataAndCache<FetchTask: ServerTask>(using task: FetchTask, caching: Caching = .localFirst, location: CacheLocation = .default) async throws -> DataAndLocalCache? {
		
		let url = task.url

		switch caching {
		case .skipLocal, .never:
			return try await download(using: task, caching: caching, location: location)
			
		case .localFirst:
			if let data = fetchLocal(for: url, location: location) { return data }
			return try await download(using: task, caching: caching, location: location)

		case .localIfNewer(let date):
			if let data = fetchLocal(for: url, location: location, newerThan: date) { return data }
			return try await download(using: task, caching: caching, location: location)

		case .localOnly:
			return fetchLocal(for: url, location: location)

		}
	}
	
	func download<Task: ServerTask>(using task: Task, caching: Caching, location: CacheLocation) async throws -> DataAndLocalCache {
		let data = try await task.downloadData()

		if caching != .never {
			let localURL = location.location(of: task.url, relativeTo: cachesDirectory)
			try? FileManager.default.createDirectory(at: localURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
			try? data.write(to: localURL)
			return DataAndLocalCache(data: data, url: localURL)
		}
		return DataAndLocalCache(data: data, url: nil)
	}
	
	func fetchLocal(for url: URL, location: CacheLocation = .default, newerThan: Date? = nil) -> DataAndLocalCache? {
		let localURL = location.location(of: url, relativeTo: cachesDirectory)

		if !FileManager.default.fileExists(atPath: localURL.path) { return nil }
		if let limit = newerThan {
			guard
				let attributes = try? FileManager.default.attributesOfItem(atPath: localURL.path),
				let date = attributes[.creationDate] as? Date,
				date > limit
			else { return nil }
		}
		
		guard let data = try? Data(contentsOf: localURL) else { return nil }
		return DataAndLocalCache(data: data, url: localURL)
	}
	
	struct DataAndLocalCache {
		let data: Data
		let url: URL?
	}
}

extension DataCache {
	public enum Caching: Equatable { case skipLocal, localFirst, localIfNewer(Date), localOnly, never }
	public enum CacheLocation { case `default`, keyed(String), fixed(URL), grouped(String, String?)
		func location(of url: URL, relativeTo parent: URL) -> URL {
			switch self {
			case .default:
				return parent.appendingPathComponent(url.cacheKey + ".dat")

			case .keyed(let key):
				return parent.appendingPathComponent(key)
				
			case .fixed(let location):
				return location
				
			case .grouped(let group, let key):
				return parent.appendingPathComponent(group).appendingPathComponent(key ?? (url.cacheKey + ".dat"))

			}
		}
		
		var group: String? {
			switch self {
			case .grouped(let group, _): return group
			default: return nil
			}
		}
		
		func container(relativeTo parent: URL) -> URL? {
			switch self {
			case .grouped(let group, _):
				return parent.appendingPathComponent(group)
			default:
				return nil
			}
		}
		
		func key(for url: URL) -> String {
			switch self {
			case .default:
				return url.cacheKey

			case .keyed(let key):
				return key
				
			case .fixed:
				return url.cacheKey
				
			case .grouped(let group, let key):
				return group + "/" + (key ?? (url.cacheKey + ".dat"))

			}
		}

		func localURL(for remote: URL, key: String?, group: String?, parent: URL, preferred: URL?) -> URL {
			if let location = preferred { return location }
			
			let actualKey = key ?? (remote.cacheKey + ".dat")
			
			if let group = group {
				return parent.appendingPathComponent(group).appendingPathComponent(actualKey)
			}
			
			return parent.appendingPathComponent(actualKey)
		}
	}
}

