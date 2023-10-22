//
//  URLSession.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 1/29/22.
//

import Foundation

@available(macOS 10.15, iOS 13.0, watchOS 7.0, *)
extension ConveySession {
	func downloadFile(from request: URLRequest, to destination: URL) async throws {
		let _: Void = try await withUnsafeThrowingContinuation { continuation in
			let task = session.downloadTask(with: request) { url, response, error in
				if let error {
					continuation.resume(throwing: error)
				} else if let url {
					try? FileManager.default.removeItem(at: destination)
					do {
						try FileManager.default.moveItem(at: url, to: destination)
						continuation.resume()
					} catch {
						continuation.resume(throwing: error)
					}
				} else {
					continuation.resume(throwing: ConveyServerError.unknownResponse(Data(), response))
				}
			}
			task.resume()
		}
	}
	
	func data(from request: URLRequest) async throws -> ServerReturned {
		try await withUnsafeThrowingContinuation { continuation in
			let startedAt = Date()
			
			let task = session.dataTask(with: request) { data, response, error in
				guard let data = data, let response = response else {
					let error = error ?? URLError(.badServerResponse)
					return continuation.resume(throwing: error)
				}
				
				guard let httpResponse = response as? HTTPURLResponse else {
					return continuation.resume(throwing: ConveyServerError.unknownResponse(data, response))
				}
				
				continuation.resume(returning: ServerReturned(response: httpResponse, data: data, fromCache: false, duration: abs(startedAt.timeIntervalSinceNow)))
			}
			
			task.resume()
		}
	}
}
