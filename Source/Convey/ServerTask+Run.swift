//
//  ServerTask+Run.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 9/11/21.
//

import Suite

public extension PayloadDownloadingTask {
	func download() -> AnyPublisher<DownloadPayload, HTTPError> {
		fetch()
	}
}

public extension ServerTask {
	var server: Server { Server.instance }
	
	func fetch<Payload: Decodable>(decoder: JSONDecoder? = nil) -> AnyPublisher<Payload, HTTPError> {
		run()
			.decode(type: Payload.self, decoder: decoder ?? server.defaultDecoder)
			.mapError { HTTPError(url, $0) }
			.eraseToAnyPublisher()
	}
	
	func run() -> AnyPublisher<Data, HTTPError> {
		buildRequest()
			.mapError { HTTPError.other($0) }
			.flatMap { (request: URLRequest) -> AnyPublisher<Data, HTTPError> in
				server.session.dataTaskPublisher(for: request)
					.assumeHTTP()
					.preprocess(using: self)
					.responseData()
					.eraseToAnyPublisher()
			}
			.eraseToAnyPublisher()
	}
	
	var url: URL {
		if let custom = self as? CustomURLTask, let customURL = custom.customURL { return customURL }
		
		return server.url(forPath: path)
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
