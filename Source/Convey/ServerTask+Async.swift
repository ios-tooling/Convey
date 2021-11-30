//
//  ServerTask+Async.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 10/30/21.
//

import Suite

@available(macOS 12.1, iOS 15.0, watchOS 8.0, *)
public protocol CustomAsyncURLRequestTask: ServerTask {
	var customURLRequest: URLRequest { get async throws }
}


@available(macOS 12.1, iOS 15.0, watchOS 8.0, *)
public extension PayloadDownloadingTask {
	func download(caching: CachePolicy = .skipLocal, decoder: JSONDecoder? = nil, preview: PreviewClosure? = nil) async throws -> DownloadPayload {
		let result: DownloadPayload = try await fetch(caching: caching, decoder: decoder, preview: preview)
		postprocess(payload: result)
		return result
	}
}

@available(macOS 12.1, iOS 15.0, watchOS 8.0, *)
public extension ServerTask {
	func send(caching: CachePolicy = .skipLocal, preview: PreviewClosure? = nil) async throws -> Data {
		try await run(caching: caching, preview: preview)
	}

	internal func fetch<Payload: Decodable>(caching: CachePolicy = .skipLocal, decoder: JSONDecoder? = nil, preview: PreviewClosure? = nil) async throws -> Payload {
		let result = try await run(caching: caching, preview: preview)
		let actualDecoder = decoder ?? server.defaultDecoder
		let decoded = try actualDecoder.decode(Payload.self, from: result)
		return decoded
	}

	internal func run(caching: CachePolicy = .skipLocal, preview: PreviewClosure? = nil) async throws -> Data {
		if caching == .skipRemote, self is ServerCacheableTask {
			if let data = DataCache.instance.cachedValue(for: url) {
				return data
			}
			throw HTTPError.offline
		}

		do {
			return try await submit(caching: caching, preview: preview).data
		} catch {
			if error.isOffline, self is ServerCacheableTask {
				return try await run(caching: .skipLocal, preview: preview)
			}
			if error.isOffline, self is FileBackedTask, let data = fileCachedData {
				return data
			}
			throw error
		}
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

	internal func submit(caching: CachePolicy = .skipLocal, preview: PreviewClosure? = nil) async throws -> (data: Data, response: HTTPURLResponse) {
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
