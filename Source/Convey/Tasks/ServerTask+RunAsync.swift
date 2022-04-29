//
//  ServerTask+Async.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 10/30/21.
//

import Suite
import Foundation

@available(macOS 11, iOS 13.0, watchOS 7.0, *)
public protocol CustomAsyncURLRequestTask: ServerTask {
	var customURLRequest: URLRequest { get async throws }
}


@available(macOS 11, iOS 13.0, watchOS 7.0, *)
public extension PayloadDownloadingTask {
	func download(caching: URLRequest.CachePolicy = .reloadIgnoringLocalCacheData, decoder: JSONDecoder? = nil, preview: PreviewClosure? = nil) async throws -> DownloadPayload {
		try await downloadWithResponse().payload
	}
	
	func downloadWithResponse(caching: URLRequest.CachePolicy = .reloadIgnoringLocalCacheData, decoder: JSONDecoder? = nil, preview: PreviewClosure? = nil) async throws -> (payload: DownloadPayload, response: URLResponse) {
		let result: (payload: DownloadPayload, response: URLResponse) = try await requestPayload(caching: caching, decoder: decoder, preview: preview)
		postprocess(payload: result.payload)
		return result
	}
}

@available(macOS 11, iOS 13.0, watchOS 7.0, *)
public extension ServerTask {
	func downloadData(caching: URLRequest.CachePolicy = .reloadIgnoringLocalCacheData, preview: PreviewClosure? = nil) async throws -> Data {
		try await downloadDataWithResponse(caching: caching, preview: preview).data
	}

	func downloadDataWithResponse(caching: URLRequest.CachePolicy = .reloadIgnoringLocalCacheData, preview: PreviewClosure? = nil) async throws -> (data: Data, response: URLResponse) {
		try await requestData(caching: caching, preview: preview)
	}

	func buildRequest() async throws -> URLRequest {
		if let custom = self as? CustomAsyncURLRequestTask {
			return try await custom.customURLRequest
		}
		
		if let custom = self as? CustomURLRequestTask {
			return try await withCheckedThrowingContinuation { continuation in
				custom.customURLRequest
					.onCompletion { result in
						switch result {
						case .failure(let err):
							continuation.resume(throwing: err)
							
						case .success(let request):
							continuation.resume(returning: request ?? defaultRequest())
						}
					}
			}
		}
			
		return defaultRequest()
	}
}


@available(macOS 11, iOS 13.0, watchOS 7.0, *)
extension ServerTask {
	func requestPayload<Payload: Decodable>(caching: URLRequest.CachePolicy = .reloadIgnoringLocalCacheData, decoder: JSONDecoder? = nil, preview: PreviewClosure? = nil) async throws -> (payload: Payload, response: URLResponse) {
		let result = try await requestData(caching: caching, preview: preview)
		let actualDecoder = decoder ?? server.defaultDecoder
        do {
            let decoded = try actualDecoder.decode(Payload.self, from: result.data)
            return (payload: decoded, response: result.response)
        } catch {
            print("Error when decoding \(Payload.self) in \(self): \(error)")
            throw error
        }
	}

	func requestData(caching: URLRequest.CachePolicy = .reloadIgnoringLocalCacheData, preview: PreviewClosure? = nil) async throws -> (data: Data, response: URLResponse) {
		if caching == .returnCacheDataDontLoad, self is ServerCacheableTask {
			if let data = DataCache.instance.cachedValue(for: url) {
				return (data: data, response: URLResponse(cachedFor: url, data: data))
			}
			throw HTTPError.offline
		}

		do {
			return try await internalRequestData(preview: preview)
		} catch {
			if error.isOffline, self is ServerCacheableTask {
				return try await requestData(caching: .reloadIgnoringLocalCacheData, preview: preview)
			}
			if error.isOffline, self is FileBackedTask, let data = fileCachedData {
				return (data: data, response: URLResponse(cachedFor: url, data: data))
			}
			throw error
		}
	}
	
	func internalRequestData(preview: PreviewClosure? = nil) async throws -> (data: Data, response: HTTPURLResponse) {
		let startedAt = Date()
		var request = try await buildRequest()
		request = try await server.preflight(self, request: request)
		preLog(startedAt: Date(), request: request)
		
		let result = try await server.data(for: request)
		if self is FileBackedTask { self.fileCachedData = result.data }
		postLog(startedAt: startedAt, request: request, data: result.data, response: result.response)
		preview?(result.data, result.response)
		postprocess(data: result.data, response: result.response)
		return result
	}

}
