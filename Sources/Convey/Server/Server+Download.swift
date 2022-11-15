//
//  Server+Download.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 9/12/21.
//

import Foundation
import Combine

@available(macOS 10.15, iOS 13.0, watchOS 7.0, *)
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
