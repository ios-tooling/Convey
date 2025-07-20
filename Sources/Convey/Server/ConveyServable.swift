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
	var downloadQueue: OperationQueue { get }
	
	func url(for task: any DownloadingTask) async -> URL
	func session(for task: any DownloadingTask) async throws -> ConveySession
	func headers(for task: any DownloadingTask) async -> Headers
}

public extension ConveyServerable {
	var baseURL: URL { remote.url }
	var defaultTaskConfiguration: TaskConfiguration { .default }
	var defaultDecoder: JSONDecoder { .init() }
	var downloadQueue: OperationQueue { .main }
	
	func url(for task: any DownloadingTask) async -> URL {
		let base = await baseURL.appendingPathComponent(task.path)
		
		if let parameters = await task.queryParameters, !parameters.isEmpty {
			var components = URLComponents(url: base, resolvingAgainstBaseURL: true)
			
			if let params = parameters as? [String: String] {
				components?.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }.sorted { $0.name < $1.name }
			} else if let params = parameters as? [URLQueryItem] {
				components?.queryItems = params.sorted { $0.name < $1.name }
			}

			if let newURL = components?.url { return newURL }
		}
		return base
	}
	
	func session(for task: any DownloadingTask) async throws -> ConveySession {
		try await .init(server: self, task: task)
	}
	
	func headers(for task: any DownloadingTask) async -> Headers {
		configuration.defaultHeaders
	}
}

