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

@available(macOS 12.0.0, iOS 15.0, watchOS 8.0, *)
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

@available(macOS 12.0.0, iOS 15.0, watchOS 8.0, *)
extension URLSession {
	func data(from request: URLRequest) async throws -> (data: Data, response: URLResponse) {
		  try await withUnsafeThrowingContinuation { continuation in
				let task = self.dataTask(with: request) { data, response, error in
					 guard let data = data, let response = response else {
						  let error = error ?? URLError(.badServerResponse)
						  return continuation.resume(throwing: error)
					 }

					continuation.resume(returning: (data: data, response: response))
				}

				task.resume()
		  }
	 }
}
