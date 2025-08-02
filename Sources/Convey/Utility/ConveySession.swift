//
//  ConveySession.swift
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
	let ungzippedRequest: URLRequest?
	var tag: String? { task.requestTag }
	
	static func session(for tag: String) -> ConveySession? {
		activeSessions.first { $0.tag == tag }
	}
	
	static func cancel(sessionWithTag tag: String) {
		session(for: tag)?.cancel()
	}
	
	static var activeSessions: Set<ConveySession> = []
	
	init<Task: DownloadingTask>(server: ConveyServerable, task: Task) async throws {
		do {
			self.server = server
			self.task = task
			self.request = try await task.request
			self.ungzippedRequest = task.shouldGZIPUploads ? try await task.gzipped(false).request : nil
			
			let configuration = URLSessionConfiguration.default
			let taskConfig = task.configuration
			
			if let expensive = task.allowsExpensiveNetworkAccess { configuration.allowsExpensiveNetworkAccess = expensive }
			if let constrained = task.allowsConstrainedNetworkAccess { configuration.allowsConstrainedNetworkAccess = constrained }
			configuration.timeoutIntervalForRequest = task.timeoutIntervalForRequest ?? taskConfig?.timeout ?? server.configuration.defaultTimeout
			
			configuration.timeoutIntervalForResource = task.timeoutIntervalForResource ?? taskConfig?.timeout ?? server.configuration.defaultTimeout
			
			super.init()
			self.session = URLSession(configuration: configuration, delegate: self, delegateQueue: server.downloadQueue)
		} catch {
			throw error
		}
	}
	
	func cancel() {
		session.invalidateAndCancel()
	}
	
	func finish() {
		Self.activeSessions.remove(self)
	}
}

extension ConveySession {
	func fetchData() async throws -> (Data, URLResponse, Int) {
		var attemptNumber = 0
		
		while true {
			do {
				let (data, response) = try await session.data(for: request)
				return (data, response, attemptNumber + 1)
			} catch let error as URLError {
				if error.code != .timedOut { throw error }
				attemptNumber += 1
				guard let delay = task.retryInterval(afterCount: attemptNumber) else { break }
				if #available(iOS 16.0, *) {
					try await Task.sleep(for: .seconds(delay))
				} else {
					try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
				}
			} catch {
				throw error
			}
		}
		throw URLError(.timedOut)
	}
}

extension ConveySession: URLSessionDelegate {
	
}
