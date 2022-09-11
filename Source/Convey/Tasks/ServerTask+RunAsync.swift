//
//  ServerTask+Async.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 10/30/21.
//

import Foundation
import Combine

public struct DownloadResult<Payload> {
	public init(payload: Payload, response: HTTPURLResponse, data: Data?, fromCache: Bool) {
		self.payload = payload
		self.response = response
		self.data = data
		self.fromCache = fromCache
	}
	
	public let payload: Payload
	public let response: HTTPURLResponse
	public let data: Data?
	public let fromCache: Bool
}

public struct RawDownloadResult {
	public let response: HTTPURLResponse
	public let data: Data
	public let fromCache: Bool
}

@available(macOS 10.15, iOS 13.0, watchOS 7.0, *)
public extension PayloadDownloadingTask {
	func download(caching: DataCache.Caching = .skipLocal, decoder: JSONDecoder? = nil, preview: PreviewClosure? = nil) async throws -> DownloadPayload {
		try await downloadWithResponse().payload
	}
	
	func downloadWithResponse(caching: DataCache.Caching = .skipLocal, decoder: JSONDecoder? = nil, preview: PreviewClosure? = nil) async throws -> DownloadResult<DownloadPayload> {
		let result: DownloadResult<DownloadPayload> = try await requestPayload(caching: caching, decoder: decoder, preview: preview)
		postprocess(payload: result.payload)
		return result
	}
}

@available(macOS 10.15, iOS 13.0, watchOS 7.0, *)
public extension ServerTask where Self: ServerDELETETask {
    func delete() async throws {
        _ = try await self.downloadData()
    }
}

@available(macOS 10.15, iOS 13.0, watchOS 7.0, *)
public extension ServerTask {
	func downloadData(caching: DataCache.Caching = .skipLocal, preview: PreviewClosure? = nil) async throws -> Data {
		try await downloadDataWithResponse(caching: caching, preview: preview).data
	}

	func downloadDataWithResponse(caching: DataCache.Caching = .skipLocal, preview: PreviewClosure? = nil) async throws -> RawDownloadResult {
		try await requestData(caching: caching, preview: preview)
	}

	func buildRequest() async throws -> URLRequest {
		if let custom = self as? CustomAsyncURLRequestTask {
			return try await custom.customURLRequest
		}

		return defaultRequest()
	}
}


@available(macOS 10.15, iOS 13.0, watchOS 7.0, *)
extension ServerTask {
    func requestPayload<Payload: Decodable>(caching: DataCache.Caching = .skipLocal, decoder: JSONDecoder? = nil, preview: PreviewClosure? = nil) async throws -> DownloadResult<Payload> {
		let result = try await requestData(caching: caching, preview: preview)
		let actualDecoder = decoder ?? server.defaultDecoder
        do {
            let decoded = try actualDecoder.decode(Payload.self, from: result.data)
            return DownloadResult(payload: decoded, response: result.response, data: result.data, fromCache: false)
        } catch {
			  print("Error when decoding \(Payload.self) in \(self), \(String(data: result.data, encoding: .utf8) ?? "--unparseable--"): \(error)")
            throw error
        }
	}

	func requestData(caching: DataCache.Caching = .skipLocal, preview: PreviewClosure? = nil) async throws -> RawDownloadResult {
		if caching == .localOnly, self is ServerCacheableTask {
			if let data = cachedData {
				return RawDownloadResult(response: HTTPURLResponse(cachedFor: url, data: data), data: data, fromCache: true)
			}
			throw HTTPError.offline
		}

		do {
			return try await sendRequest(preview: preview)
		} catch {
			if error.isOffline, self is ServerCacheableTask {
				return try await requestData(caching: .skipLocal, preview: preview)
			}
			if error.isOffline, self is FileBackedTask, let data = fileCachedData {
				return RawDownloadResult(response: HTTPURLResponse(cachedFor: url, data: data), data: data, fromCache: true)
			}
			throw error
		}
	}
	
	func sendRequest(preview: PreviewClosure? = nil) async throws -> RawDownloadResult {
		var attemptCount = 1
		
		while true {
			do {
				if let threadName = (self as? ThreadedServerTask)?.threadName { await server.wait(forThread: threadName) }
				let startedAt = Date()

				try await (self as? PreFlightTask)?.preFlight()
				var request = try await buildRequest()
				print("Request: \(request.allHTTPHeaderFields)")
				request = try await server.preflight(self, request: request)
				print("Request: \(request.allHTTPHeaderFields)")
				//preLog(startedAt: Date(), request: request)
				await ConveyTaskManager.instance.begin(task: self, request: request, startedAt: startedAt)

				let result = try await server.data(for: request)
				await ConveyTaskManager.instance.complete(task: self, request: request, response: result.response, bytes: result.data, startedAt: startedAt)
				if self is FileBackedTask { self.fileCachedData = result.data }
				if self is ETagCachedTask, let tag = result.response.etag {
					ETagStore.instance.store(etag: tag, for: url)
				}
				//postLog(startedAt: startedAt, request: request, data: result.data, response: result.response)
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
				return RawDownloadResult(response: result.response, data: result.data, fromCache: false)
			} catch {
				if let threadName = (self as? ThreadedServerTask)?.threadName { await server.stopWaiting(forThread: threadName) }

				if let delay = (self as? RetryableTask)?.retryInterval(after: error, attemptNumber: attemptCount) {
					attemptCount += 1
					try await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
				} else {
					throw error
				}
			}
		}
	}

}
