//
//  DataCache+Task.swift
//  PGRGuide
//
//  Created by Ben Gottlieb on 7/2/23.
//

import Foundation

extension DataCache {
	public func fetch<FetchTask: ServerTask>(using task: FetchTask, caching: Caching = .localFirst, provision: Provision? = nil) async throws -> Data? {
		try await fetchDataAndCache(using: task, caching: caching, provision: provision ?? self.provision(url: task.url))?.data
	}

	public func fetchCachedLocation<FetchTask: ServerTask>(using task: FetchTask, caching: Caching = .localFirst, provision: Provision) async throws -> URL? {
		try await fetchDataAndCache(using: task, caching: caching, provision: provision)?.url
	}

	func fetchDataAndCache<FetchTask: ServerTask>(using task: FetchTask, caching: Caching = .localFirst, provision: Provision) async throws -> DataAndLocalCache? {
		switch caching {
		case .skipLocal, .never:
			return try await download(using: task, caching: caching, provision: provision)
			
		case .localFirst:
			if let data = fetchLocal(for: provision) { return data }
			return try await download(using: task, caching: caching, provision: provision)

		case .localIfNewer(let date):
			if let data = fetchLocal(for: provision, newerThan: date) { return data }
			return try await download(using: task, caching: caching, provision: provision)

		case .localOnly:
			return fetchLocal(for: provision)

		}
	}
	
	func download<Task: ServerTask>(using task: Task, caching: Caching, provision: Provision) async throws -> DataAndLocalCache {
		let data = try await task.downloadData()

		if caching != .never {
			let localURL = cache(data: data, for: provision)
			return DataAndLocalCache(data: data, url: localURL)
		}
		return DataAndLocalCache(data: data, url: nil)
	}
	
	public func replace<Task: ServerTask>(data: Data, for task: Task, provision: Provision? = nil) throws {
		try replace(data: data, for: provision ?? self.provision(url: task.url))
	}
}
