//
//  URLSession.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 1/29/22.
//

import Foundation

@available(macOS 11, iOS 13.0, watchOS 7.0, *)
public extension URLSession {
	func cancelTasks(with tags: [String]) async {
		let allTasks = await allTasks
		
		for task in allTasks {
			if let tag = task.originalRequest?.requestTag, tags.contains(tag) {
				task.cancel()
			}
		}
	}
	
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
