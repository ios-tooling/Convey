//
//  URLSession.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 1/29/22.
//

import Foundation

@available(macOS 10.15, iOS 13.0, watchOS 7.0, *)
public extension URLSession {
	func cancelTasks(with tags: [String]) async {
		let allTasks = await allTasks
		
		for task in allTasks {
			if let tag = task.originalRequest?.requestTag, tags.contains(tag) {
				task.cancel()
			}
		}
	}
	
	func data(from request: URLRequest) async throws -> ServerReturned {
		  try await withUnsafeThrowingContinuation { continuation in
				let task = self.dataTask(with: request) { data, response, error in
					 guard let data = data, let response = response else {
						  let error = error ?? URLError(.badServerResponse)
						  return continuation.resume(throwing: error)
					 }
					
					guard let httpResponse = response as? HTTPURLResponse else {
						return continuation.resume(throwing: ServerError.unknownResponse(data, response))
					}

					continuation.resume(returning: ServerReturned(response: httpResponse, data: data, fromCache: false))
				}

				task.resume()
		  }
	 }
}
