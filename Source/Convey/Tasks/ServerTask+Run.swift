//
//  ServerTask+Run.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 9/11/21.
//

import Foundation
import Combine

public extension PayloadDownloadingTask {
	func postprocess(payload: DownloadPayload) { }
	func download(caching: DataCache.Caching = .skipLocal, decoder: JSONDecoder? = nil, preview: PreviewClosure? = nil) -> AnyPublisher<(payload: DownloadPayload, response: URLResponse), HTTPError> {
		requestPayload(caching: caching, decoder: decoder, preview: preview)
			.map { (payload: (payload: DownloadPayload, response: URLResponse)) -> (payload: DownloadPayload, response: URLResponse) in
				postprocess(payload: payload.payload)
				return payload
			}
			.eraseToAnyPublisher()
	}
	
	func cachedPayload(decoder: JSONDecoder? = nil) -> DownloadPayload? {
		guard let data = cachedData else { return nil }
		let decoder = decoder ?? server.defaultDecoder
		
		do {
			return try decoder.decode(DownloadPayload.self, from: data)
		} catch {
			print("Local requestPayload failed for \(DownloadPayload.self) \(url)\n\n \(error)\n\n\(String(data: data, encoding: .utf8) ?? "--")")
			return nil
		}
	}
}

public extension ServerTask {
	var server: Server { Server.serverInstance }

	func downloadData(caching: DataCache.Caching = .skipLocal, preview: PreviewClosure? = nil) -> AnyPublisher<(data: Data, response: URLResponse), HTTPError> {
		requestData(caching: caching, preview: preview)
	}

	func postprocess(data: Data, response: HTTPURLResponse) { }
	var url: URL {
		let nonParameterized = (self as? CustomURLTask)?.customURL ?? server.url(forTask: self)
		if let parameters = (self as? ParameterizedTask)?.parameters, !parameters.isEmpty {
			var components = URLComponents(url: nonParameterized, resolvingAgainstBaseURL: true)
			
			components?.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
			if let newURL = components?.url { return newURL }
		}

		return nonParameterized
	}

	var cachedData: Data? {
		DataCache.instance.fetchLocal(for: url)?.data
	}
}

extension ServerTask {
	func requestPayload<Payload: Decodable>(caching: DataCache.Caching = .skipLocal, decoder: JSONDecoder? = nil, preview: PreviewClosure? = nil) -> AnyPublisher<(payload: Payload, response: URLResponse), HTTPError> {
		requestData(caching: caching, preview: preview)
			.tryMap { (result: (data: Data, response: URLResponse)) -> (payload: Payload, response: URLResponse) in
				let dec = decoder ?? server.defaultDecoder
                
                do {
                    return (payload: try dec.decode(Payload.self, from: result.data), response: result.response)
                } catch {
                    print("Error when decoding \(Payload.self) in \(self), \(String(data: result.data, encoding: .utf8) ?? "--unparseable--"): \(error)")
                    throw error
                }
			}
			.mapError { HTTPError(url, $0) }
			.eraseToAnyPublisher()
	}

	func requestData(caching: DataCache.Caching = .skipLocal, preview: PreviewClosure? = nil) -> AnyPublisher<(data: Data, response: URLResponse), HTTPError> {
		if caching == .localOnly, self is ServerCacheableTask {
			if let data = cachedData {
				return Just((data: data, response: URLResponse(cachedFor: url, data: data))).setFailureType(to: HTTPError.self).eraseToAnyPublisher()
			}
			return Fail(error: HTTPError.offline).eraseToAnyPublisher()
		}
		
		return internalRequestData(preview: preview)
			.catch { error -> AnyPublisher<(data: Data, response: URLResponse), HTTPError> in
				if error.isOffline, self is ServerCacheableTask {
					return requestData(caching: .skipLocal, preview: preview)
				}
				if error.isOffline, self is FileBackedTask, let data = fileCachedData {
					return Just((data: data, response: URLResponse(cachedFor: url, data: data))).setFailureType(to: HTTPError.self).eraseToAnyPublisher()
				}
				return Fail(error: error).eraseToAnyPublisher()
			}
			.eraseToAnyPublisher()
		
	}
	
	func internalRequestData(preview: PreviewClosure? = nil) -> AnyPublisher<(data: Data, response: URLResponse), HTTPError> {
		let startedAt = Date()
		
		return buildRequest()
			.flatMap { request in server.preflight(self, request: request) }
			.map { preLog(startedAt: startedAt, request: $0); return $0 }
			.mapError { HTTPError.other($0) }
			.flatMap { (request: URLRequest) -> AnyPublisher<(data: Data, response: URLResponse), HTTPError> in
				server.data(for: request)
					.map { data in
						if self is FileBackedTask { self.fileCachedData = data.data }
						postLog(startedAt: startedAt, request: request, data: data.data, response: data.response)
						preview?(data.data, data.response)
						postprocess(data: data.data, response: data.response)
						return data
					}
					.eraseToAnyPublisher()
			}
			.eraseToAnyPublisher()
	}
}
