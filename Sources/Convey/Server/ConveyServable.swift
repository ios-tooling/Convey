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
	
	func url(for path: String) async -> URL
	func session(for task: DownloadingTask) async throws -> ConveySession
}

public extension ConveyServerable {
	var baseURL: URL { remote.url }
	var defaultTaskConfiguration: TaskConfiguration { .default }
	var defaultDecoder: JSONDecoder { .init() }
	var downloadQueue: OperationQueue { .main }
	
	func url(for path: String) async -> URL {
		baseURL.appendingPathComponent(path)
	}
	
	func session(for task: DownloadingTask) async throws -> ConveySession {
		try await .init(server: self, task: task)
	}
}

