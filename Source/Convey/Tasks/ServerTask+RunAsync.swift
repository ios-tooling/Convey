//
//  ServerTask+Async.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 10/30/21.
//

import Foundation
import Combine

@available(macOS 11, iOS 13.0, watchOS 7.0, *)
public extension PayloadDownloadingTask {
	func download(caching: URLRequest.CachePolicy = .reloadIgnoringLocalCacheData, decoder: JSONDecoder? = nil, preview: PreviewClosure? = nil) async throws -> DownloadPayload {
		try await downloadWithResponse().payload
	}
	
    func downloadWithResponse(caching: URLRequest.CachePolicy = .reloadIgnoringLocalCacheData, decoder: JSONDecoder? = nil, preview: PreviewClosure? = nil) async throws -> (payload: DownloadPayload, response: URLResponse, data: Data?) {
        let result: (payload: DownloadPayload, response: URLResponse, data: Data?) = try await requestPayload(caching: caching, decoder: decoder, preview: preview)
		postprocess(payload: result.payload)
		return result
	}
}

@available(macOS 11, iOS 13.0, watchOS 7.0, *)
public extension ServerTask where Self: ServerDELETETask {
    func delete() async throws {
        _ = try await self.downloadData()
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
            var cancellable: AnyCancellable?
			let request = try await withCheckedThrowingContinuation { continuation in
                cancellable = custom.customURLRequest
                    .sink(receiveCompletion: { result in
                        switch result {
                        case .failure(let error): continuation.resume(throwing: error)
                        case .finished: break
                        }
                    }, receiveValue: { request in
                        continuation.resume(returning: request)
                    })
			}
            
            if cancellable != nil { cancellable = nil }
            if let request = request { return request }
		}
			
		return defaultRequest()
	}
}


@available(macOS 11, iOS 13.0, watchOS 7.0, *)
extension ServerTask {
    func requestPayload<Payload: Decodable>(caching: URLRequest.CachePolicy = .reloadIgnoringLocalCacheData, decoder: JSONDecoder? = nil, preview: PreviewClosure? = nil) async throws -> (payload: Payload, response: URLResponse, data: Data?) {
		let result = try await requestData(caching: caching, preview: preview)
		let actualDecoder = decoder ?? server.defaultDecoder
        do {
            let decoded = try actualDecoder.decode(Payload.self, from: result.data)
            return (payload: decoded, response: result.response, data: result.data)
        } catch {
			  print("Error when decoding \(Payload.self) in \(self), \(String(data: result.data, encoding: .utf8) ?? "--unparseable--"): \(error)")
            throw error
        }
	}

	func requestData(caching: URLRequest.CachePolicy = .reloadIgnoringLocalCacheData, preview: PreviewClosure? = nil) async throws -> (data: Data, response: URLResponse) {
		if caching == .returnCacheDataDontLoad, self is ServerCacheableTask {
			if let data = cachedData {
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
		if let threadName = (self as? ThreadedServerTask)?.threadName { await server.wait(forThread: threadName) }
		
		let startedAt = Date()
        try await (self as? PreFlightTask)?.preFlight()
		var request = try await buildRequest()
		request = try await server.preflight(self, request: request)
		preLog(startedAt: Date(), request: request)
		
		let result = try await server.data(for: request)
		if self is FileBackedTask { self.fileCachedData = result.data }
		postLog(startedAt: startedAt, request: request, data: result.data, response: result.response)
		preview?(result.data, result.response)
		postprocess(data: result.data, response: result.response)
			if result.response.statusCode / 100 != 2 {
            server.reportConnectionError(self, result.response.statusCode, String(data: result.data, encoding: .utf8))
			   if result.data.isEmpty || (result.response.statusCode.isHTTPError && server.reportBadHTTPStatusAsError) {
                throw HTTPError.serverError(request.url, result.response.statusCode, result.data)
            }
        }
		
		try await (self as? PostFlightTask)?.postFlight()
		if let threadName = (self as? ThreadedServerTask)?.threadName { await server.stopWaiting(forThread: threadName) }
		return result
	}

}
