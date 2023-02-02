//
//  ServerTask+RefreshableCachedTask.swift
//  
//
//  Created by Ben Gottlieb on 1/30/23.
//

import Foundation

extension RefreshableCachedTask {
	public func downloadData(ignoringCacheIfOlderThan date: Date? = nil, refreshing completion: @escaping (Result<Data, Error>) -> Void) -> Data? {
		let url = self.url
		let data = DataCache.instance.fetchLocal(for: url, newerThan: date)
		
		Task {
			do {
				let result = try await self.downloadData()
				try DataCache.instance.replace(data: result, for: self, location: .default)
				completion(.success(result))
			} catch {
				completion(.failure(error))
			}
		}
		
		return data?.data
	}
}

extension RefreshableCachedTask where Self: PayloadDownloadingTask {
	public func download(ignoringCacheIfOlderThan date: Date? = nil, decoder: JSONDecoder? = nil, refreshing completion: @escaping (Result<DownloadPayload, Error>) -> Void) -> DownloadPayload? {
		let url = self.url
		let cached = DataCache.instance.fetchLocal(for: url, newerThan: date)
		let actualDecoder = decoder ?? server.defaultDecoder

		Task {
			do {
				let result = try await self.downloadWithResponse()
				try DataCache.instance.replace(data: result.response.data, for: self, location: .default)
				completion(.success(result.payload))
			} catch {
				completion(.failure(error))
			}
		}
		
		if let data = cached?.data, let payload = try? actualDecoder.decode(DownloadPayload.self, from: data) {
			return payload
		}
		return nil
	}
}
