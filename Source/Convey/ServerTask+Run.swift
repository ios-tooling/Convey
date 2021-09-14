//
//  ServerTask+Run.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 9/11/21.
//

import Suite

public extension PayloadDownloadingTask {
	func postprocess(payload: DownloadPayload) { }
	func download(caching: CachePolicy = .skipLocal, decoder: JSONDecoder? = nil, preview: PreviewClosure? = nil) -> AnyPublisher<DownloadPayload, HTTPError> {
		fetch(caching: caching, decoder: decoder, preview: preview)
			.map { (payload: DownloadPayload) -> DownloadPayload in
				postprocess(payload: payload)
				return payload
			}
			.eraseToAnyPublisher()
	}
	
	func cachedPayload(decoder: JSONDecoder? = nil) -> DownloadPayload? {
		guard let data = cachedData else { return nil }
		let decoder = decoder ?? Server.serverInstance.defaultDecoder
		
		do {
			return try decoder.decode(DownloadPayload.self, from: data)
		} catch {
			logg("Local fetch failed for \(DownloadPayload.self) \(url)\n\n \(error)\n\n\(String(data: data, encoding: .utf8) ?? "--")")
			return nil
		}

	}
}

public extension ServerTask {
	var server: Server { Server.serverInstance }
	
	func postprocess(data: Data, response: HTTPURLResponse) { }

	func fetch<Payload: Decodable>(caching: CachePolicy = .skipLocal, decoder: JSONDecoder? = nil, preview: PreviewClosure? = nil) -> AnyPublisher<Payload, HTTPError> {
		run(caching: caching, preview: preview)
			.decode(type: Payload.self, decoder: decoder ?? server.defaultDecoder)
			.mapError { HTTPError(url, $0) }
			.eraseToAnyPublisher()
	}

	func run(caching: CachePolicy = .skipLocal, preview: PreviewClosure? = nil) -> AnyPublisher<Data, HTTPError> {
		if caching == .skipRemote, self is ServerCacheableTask {
			if let data = DataCache.instance.cachedValue(for: url) {
				return Just(data).setFailureType(to: HTTPError.self).eraseToAnyPublisher()
			}
			return Fail(error: HTTPError.offline).eraseToAnyPublisher()
		}
		
		return submit(caching: caching, preview: preview)
			.responseData()
			.catch { error -> AnyPublisher<Data, HTTPError> in
				if error.isOffline, self is ServerCacheableTask {
					return run(caching: .skipLocal, preview: preview)
				}
				return Fail(error: error).eraseToAnyPublisher()
			}
			.eraseToAnyPublisher()
		
	}
	
	func submit(caching: CachePolicy = .skipLocal, preview: PreviewClosure? = nil) -> AnyPublisher<(data: Data, response: HTTPURLResponse), HTTPError> {
		return buildRequest()
			.mapError { HTTPError.other($0) }
			.flatMap { (request: URLRequest) -> AnyPublisher<(data: Data, response: HTTPURLResponse), HTTPError> in
				server.data(for: request)
					.map { data in
						preview?(data.data, data.response);
						postprocess(data: data.data, response: data.response)
						return data
					}
					.eraseToAnyPublisher()
			}
			.eraseToAnyPublisher()
	}
	
	var url: URL {
		let base = (self as? CustomURLTask)?.customURL ?? server.url(forPath: path)
		if let parameters = (self as? ParamaterizedTask)?.parameters {
			var components = URLComponents(url: base, resolvingAgainstBaseURL: true)
			
			components?.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
			if let newURL = components?.url { return newURL }
		}

		return base
	}

	var cachedData: Data? {
		DataCache.instance.cachedValue(for: url)
	}
}
