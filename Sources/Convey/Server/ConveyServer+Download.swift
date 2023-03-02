//
//  ConveyServer+Download.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 9/12/21.
//

import Foundation
import Combine

@available(macOS 10.15, iOS 13.0, watchOS 7.0, *)
public extension ConveyServer {
	func data(for url: URL) async throws -> ServerReturned {
		try await data(for: URLRequest(url: url))
	}
	
	func data(for request: URLRequest) async throws -> ServerReturned {
		try await session.data(from: request)
	}
}
