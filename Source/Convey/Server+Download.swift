//
//  Server+Download.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 9/12/21.
//

import Suite

public extension Server {
	func data(for url: URL) -> AnyPublisher<(data: Data, response: HTTPURLResponse), HTTPError> {
		data(for: URLRequest(url: url))
	}
	
	func data(for request: URLRequest) -> AnyPublisher<(data: Data, response: HTTPURLResponse), HTTPError> {
		session.dataTaskPublisher(for: request)
			.map { data, response in
				return (data, response)
			}
			.assumeHTTP()
			.eraseToAnyPublisher()
		
	}
}
