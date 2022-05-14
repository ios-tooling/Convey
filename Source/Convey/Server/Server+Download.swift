//
//  Server+Download.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 9/12/21.
//

import Suite
import Foundation

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

@available(macOS 11, iOS 13.0, watchOS 7.0, *)
public extension Server {
	func data(for url: URL) async throws -> (data: Data, response: HTTPURLResponse) {
		try await data(for: URLRequest(url: url))
	}
	
	func data(for request: URLRequest) async throws -> (data: Data, response: HTTPURLResponse) {
		let result = try await session.data(from: request)
		
		guard let response = result.response as? HTTPURLResponse else {
			throw HTTPError.nonHTTPResponse(request.url, result.data)
		}
		
		return (result.data, response)
	}
}
