//
//  ConveyServerable.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/19/25.
//

import Foundation

@ConveyActor public protocol ConveyServerable {
	var remote: Remote { get set }
	var baseURL: URL { get }
	var configuration: ServerConfiguration { get set }
	var defaultTaskConfiguration: TaskConfiguration { get }
	var defaultDecoder: JSONDecoder { get }
	var downloadQueue: OperationQueue? { get }
	
	func url(for task: any DownloadingTask) async -> URL
	func session(for task: any DownloadingTask) async throws -> ConveySession
	func headers(for task: any DownloadingTask) async throws -> Headers
	func didFinish<T: DownloadingTask>(task: T, response: ServerResponse<Data>?, error: (any Error)?) async
}

public extension ConveyServerable {
	var baseURL: URL { remote.url }
	var defaultTaskConfiguration: TaskConfiguration { .default }
	var defaultDecoder: JSONDecoder { configuration.defaultDecoder }
	var downloadQueue: OperationQueue? { nil }
	
	func cancelTasks(with tags: [String]) async {
		for tag in tags {
			ConveySession.cancel(sessionWithTag: tag)
		}
	}
	
	func defaultHeaders(for task: any DownloadingTask) async -> Headers {
		var headers = configuration.defaultHeaders.headersArray
		if let userAgent = configuration.userAgent {
			headers.append(header: Constants.Headers.userAgent, value: userAgent) }
		headers.append(header: Constants.Headers.accept, value: task.acceptType)
		return headers
	}

	func url(for task: any DownloadingTask) async -> URL {
		await baseURL(for: task.path, queryParameters: task.queryParameters)
	}
	
	func baseURL(for path: String, queryParameters parameters: (any TaskQueryParameters)?) async -> URL {
		let base = baseURL.appendingPathComponent(path)
		
		if let parameters, !parameters.isEmpty, var components = URLComponents(url: base, resolvingAgainstBaseURL: true) {
			var queryItems: [URLQueryItem] = []
			
			if let params = parameters as? [String: String] {
				queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
			} else if let params = parameters as? [URLQueryItem] {
				queryItems = params
			}

			components.queryItems = queryItems.sorted { $0.name < $1.name }
			if let newURL = components.url { return newURL }
		}
		return base
	}
	
	func session(for task: any DownloadingTask) async throws -> ConveySession {
		try await ConveySession(server: self, task: task)
	}
	
	func headers(for task: any DownloadingTask) async throws -> Headers {
		await defaultHeaders(for: task)
	}
	
	func didFinish<T: DownloadingTask>(task: T, response: ServerResponse<Data>?, error: (any Error)?) async {
		
	}
}

