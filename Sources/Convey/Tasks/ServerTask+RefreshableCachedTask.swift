//
//  ServerTask+RefreshableCachedTask.swift
//  
//
//  Created by Ben Gottlieb on 1/30/23.
//

import Foundation

public typealias RefreshableCompletion = (Result<Data, Error>) -> Void
public enum CachedDataFetchStyle: Sendable { case cachedOnly, forceRefetch, cachedThenFetched, cachedThenForceRefresh }

extension RefreshableCachedTask {
	public func fetchData(decoder: JSONDecoder? = nil, ignoringCacheIfOlderThan interval: TimeInterval, style: CachedDataFetchStyle = .cachedThenFetched, refreshing completion: RefreshableCompletion? = nil) async throws -> Data? {
		try await fetchData(decoder: decoder, ignoringCacheIfOlderThan: Date().addingTimeInterval(-interval), style: style, refreshing: completion)
	}

	
	public func fetchData(decoder: JSONDecoder? = nil, ignoringCacheIfOlderThan date: Date? = nil, style: CachedDataFetchStyle = .cachedThenFetched, refreshing completion: RefreshableCompletion? = nil) async throws -> Data? {
		let url = self.url
		let data = DataCache.instance.fetchLocal(for: url, newerThan: date)
		
		switch style {
		case .cachedOnly: break
		case .cachedThenFetched:
			if data != nil { break }
			fallthrough
			
		case .cachedThenForceRefresh:
			if let completion {
				Task {
					do {
						let result = try await self.downloadData()
						try DataCache.instance.replace(data: result, for: self)
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
			print(fresh)
			if let _ = try? (self as? (any PayloadDownloadingTask))?.decode(data: fresh, decoder: decoder) {
				try DataCache.instance.replace(data: fresh, for: self)
			} else {
				return nil
			}
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
		
		let newCompletion = { (result: Result<Data, Error>) -> Void in
			switch result {
			case .success(let data):
				do {
					let result = try decode(data: data, decoder: decoder)
					completion?(.success(result))
				} catch {
					completion?(.failure(error))
				}
				
			case .failure(let error):
				completion?(.failure(error))
			}
		}
		
		guard let cached = try await fetchData(decoder: decoder, ignoringCacheIfOlderThan: date, style: style, refreshing: completion == nil ? nil : newCompletion) else { throw HTTPError.noCachedData }
		
		return try decode(data: cached, decoder: decoder)
	}
}
