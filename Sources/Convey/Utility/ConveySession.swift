//
//  File.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/19/25.
//

import Foundation

@ConveyActor public class ConveySession: NSObject {
	let server: ConveyServerable
	var session: URLSession!
	let task: any DownloadingTask
	let request: URLRequest
	
	init<Task: DownloadingTask>(server: ConveyServerable, task: Task) async throws {
		self.server = server
		self.task = task
		self.request = try await task.request
		
		let configuration = URLSessionConfiguration.default
		
		if let expensive = task.allowsExpensiveNetworkAccess { configuration.allowsExpensiveNetworkAccess = expensive }
		if let constrained = task.allowsConstrainedNetworkAccess { configuration.allowsConstrainedNetworkAccess = constrained }
		if let requestTimeout = task.timeoutIntervalForRequest { configuration.timeoutIntervalForRequest = requestTimeout }
		if let resourceTimeout = task.timeoutIntervalForResource { configuration.timeoutIntervalForResource = resourceTimeout }

		super.init()
		self.session = URLSession(configuration: configuration, delegate: self, delegateQueue: server.downloadQueue)
	}
}

extension ConveySession {
	func fetchData() async throws -> (Data, URLResponse, Int) {
		var attemptNumber = 0
		let retryCount = task.retryCount
		
		while retryCount <= attemptNumber {
			do {
				let (data, response) = try await session.data(for: request)
				return (data, response, attemptNumber + 1)
			} catch let error as URLError {
				if error.code != .timedOut { throw error }
				attemptNumber += 1
			} catch {
				throw error
			}
		}
		throw URLError(.timedOut)
	}
}

extension ConveySession: URLSessionDelegate {
	
}
