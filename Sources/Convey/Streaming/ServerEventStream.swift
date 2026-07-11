//
//  ServerEventStream.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/10/26.
//

import Foundation

@available(iOS 15, macOS 12, watchOS 8, *)
public struct ServerEventStream: Sendable {
	public let request: URLRequest
	public let response: HTTPURLResponse
	public let events: AsyncThrowingStream<ServerSentEvent, Error>

	public var statusCode: Int { response.statusCode }
}

@available(iOS 15, macOS 12, watchOS 8, *)
extension ServerEventStream: AsyncSequence {
	public typealias Element = ServerSentEvent

	public func makeAsyncIterator() -> AsyncThrowingStream<ServerSentEvent, Error>.Iterator {
		events.makeAsyncIterator()
	}
}

@available(iOS 15, macOS 12, watchOS 8, *)
extension ConveySession {
	func openByteStream() async throws -> (URLSession.AsyncBytes, URLResponse) {
		try await session.bytes(for: request)
	}
}
