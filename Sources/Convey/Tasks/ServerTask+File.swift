//
//  ServerTask+File.swift
//  
//
//  Created by Ben Gottlieb on 9/7/23.
//

import Foundation

public extension ServerTask {
	func downloadFile(to destination: URL) async throws {
		var attemptCount = 1
		
		let token = requestBackgroundTime()
		
		while true {
			do {
				if let threadName = (self as? ThreadedServerTask)?.threadName { await server.wait(forThread: threadName) }
				let startedAt = Date()

				try await (self as? PreFlightTask)?.preFlight()
				var request = try await buildRequest()
				request = try await server.preflight(self, request: request)
				await ConveyTaskManager.instance.begin(task: self, request: request, startedAt: startedAt)
				
				try await server.session.downloadFile(from: request, to: destination)
				
				try await (self as? PostFlightTask)?.postFlight()
				if let threadName = (self as? ThreadedServerTask)?.threadName { await server.stopWaiting(forThread: threadName) }
				finishBackgroundTime(token)
				return
			} catch {
				if let threadName = (self as? ThreadedServerTask)?.threadName { await server.stopWaiting(forThread: threadName) }

				if let delay = (self as? RetryableTask)?.retryInterval(after: error, attemptNumber: attemptCount) {
					attemptCount += 1
					try await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
					finishBackgroundTime(token)
				} else {
					finishBackgroundTime(token)
					throw error
				}
			}
		}
	}


}
