//
//  ServerTask+ServerEvents.swift
//
//
//  Created by Ben Gottlieb on 10/16/23.
//

import Foundation

public enum ServerSentEventError: Error { case cancelled }

extension ServerTask where Self: ServerSentEventTargetTask {
	public func eventStream() async throws -> AsyncStream<ServerEvent> {
		try await handleThreadAndBackgrounding {
			let startedAt = Date()
			
			let request = try await beginRequest(at: startedAt)
			let session = ConveySession(task: self)
			
			return try session.start(request: request)
		}
	}

	public func stream<Element: Codable>(_ result: Element.Type, shouldCancel: @escaping () -> Bool = { false }) async throws -> AsyncThrowingStream<Element, Error> {
		let stream: AsyncThrowingStream<Element, Error> = try await self.stream(shouldCancel: shouldCancel)
		return stream
	}
	
	public func stream<Element: Codable>(shouldCancel: @escaping () -> Bool = { false }) async throws -> AsyncThrowingStream<Element, Error> {
		let stream = try await eventStream()
		
		return AsyncThrowingStream(Element.self) { continuation in
			Task {
				for await event in stream {
					if shouldCancel() {
						print("Cancelling")
						continuation.finish(throwing: ServerSentEventError.cancelled)
						return
					}
					
					if let string = event.data, let data = string.data(using: .utf8) {
						do {
							let element = try JSONDecoder().decode(Element.self, from: data)
							continuation.yield(element)
						} catch {
							print("Failed to decode \(event.data ?? "<no data>")")
							continuation.finish(throwing: error)
						}
					}
				}
				continuation.finish()
			}
		}
	}
}
