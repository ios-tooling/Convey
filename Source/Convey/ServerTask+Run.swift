//
//  ServerTask+Run.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 9/11/21.
//

import Suite

public extension PayloadDownloadingTask {
	func download(decoder: JSONDecoder? = nil, preview: PreviewClosure?) -> AnyPublisher<DownloadPayload, HTTPError> {
		fetch(decoder: decoder, preview: preview)
	}
}

public extension ServerTask {
	var server: Server { Server.instance }
	
	func fetch<Payload: Decodable>(decoder: JSONDecoder? = nil, preview: PreviewClosure? = nil) -> AnyPublisher<Payload, HTTPError> {
		run(preview: preview)
			.decode(type: Payload.self, decoder: decoder ?? server.defaultDecoder)
			.mapError { HTTPError(url, $0) }
			.eraseToAnyPublisher()
	}
	
	func run(preview: PreviewClosure? = nil) -> AnyPublisher<Data, HTTPError> {
		buildRequest()
			.mapError { HTTPError.other($0) }
			.flatMap { (request: URLRequest) -> AnyPublisher<Data, HTTPError> in
				server.session.dataTaskPublisher(for: request)
					.assumeHTTP()
					.map { data in preview?(data.data, data.response); return data }
					.preprocess(using: self)
					.responseData()
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
	

}

public extension Publisher where Output == (data: Data, response: HTTPURLResponse), Failure == HTTPError {
	func preprocess(using task: ServerTask) -> AnyPublisher<(data: Data, response: HTTPURLResponse), HTTPError> {
		tryMap { data, response in
			if let custom = task as? PreprocessingTask, let error = custom.preprocess(data: data, response: response) {
				throw error
			}
			return (data, response)
		}
		.mapError { HTTPError(task.url, $0) }
		.eraseToAnyPublisher()
	}
}
