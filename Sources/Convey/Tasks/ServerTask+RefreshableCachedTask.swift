//
//  ServerTask+RefreshableCachedTask.swift
//  
//
//  Created by Ben Gottlieb on 1/30/23.
//

import Foundation

public typealias RefreshableCompletion = (Result<Data, Error>) -> Void
public enum CachedDataFetchStyle { case cachedOnly, forceRefetch, cachedThenFetched, cachedThenForceRefresh }

extension RefreshableCachedTask {
	public func fetchData(ignoringCacheIfOlderThan interval: TimeInterval, style: CachedDataFetchStyle = .cachedThenFetched, refreshing completion: RefreshableCompletion? = nil) async throws -> Data? {
		try await fetchData(ignoringCacheIfOlderThan: Date().addingTimeInterval(-interval), style: style, refreshing: completion)
	}

	
	public func fetchData(ignoringCacheIfOlderThan date: Date? = nil, style: CachedDataFetchStyle = .cachedThenFetched, refreshing completion: RefreshableCompletion? = nil) async throws -> Data? {
		let url = self.url
		let data = DataCache.instance.fetchLocal(for: url, newerThan: date)
		
		switch style {
		case .cachedOnly: break
		case .cachedThenFetched:
			if date != nil { break }
			fallthrough
			
		case .cachedThenForceRefresh:
			if let completion {
				Task {
					do {
						let result = try await self.downloadData()
						try DataCache.instance.replace(data: result, for: self, location: .default)
						completion(.success(result))
					} catch {
						completion(.failure(error))
					}
				}
			} else {
				fallthrough
			}
			
		case .forceRefetch:
			let fresh = try await self.downloadData()
			try DataCache.instance.replace(data: fresh, for: self, location: .default)
			return fresh
		}
		
		return data?.data
	}
}

extension RefreshableCachedTask where Self: PayloadDownloadingTask {
	public func fetchPayload(ignoringCacheIfOlderThan interval: TimeInterval, style: CachedDataFetchStyle = .cachedThenFetched, decoder: JSONDecoder? = nil, refreshing completion: ((Result<DownloadPayload, Error>) -> Void)? = nil) async throws -> DownloadPayload {
		try await fetchPayload(ignoringCacheIfOlderThan: Date().addingTimeInterval(-interval), style: style, decoder: decoder, refreshing: completion)
	}
	
	public func fetchPayload(ignoringCacheIfOlderThan date: Date? = nil, style: CachedDataFetchStyle = .cachedThenFetched, decoder: JSONDecoder? = nil, refreshing completion: ((Result<DownloadPayload, Error>) -> Void)? = nil) async throws -> DownloadPayload {
		
		let actualDecoder = decoder ?? server.defaultDecoder
		let newCompletion = { (result: Result<Data, Error>) -> Void in
			switch result {
			case .success(let data):
				do {
					let result = try actualDecoder.decode(DownloadPayload.self, from: data)
					completion?(.success(result))
				} catch {
					completion?(.failure(error))
				}
				
			case .failure(let error):
				completion?(.failure(error))
			}
		}
		
		guard let cached = try await fetchData(ignoringCacheIfOlderThan: date, style: style, refreshing: completion == nil ? nil : newCompletion) else { throw HTTPError.noCachedData }
		
		return try actualDecoder.decode(DownloadPayload.self, from: cached)
	}
}
