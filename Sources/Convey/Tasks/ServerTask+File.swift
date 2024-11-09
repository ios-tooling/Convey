//
//  ServerTask+File.swift
//  
//
//  Created by Ben Gottlieb on 9/7/23.
//

import Foundation

public extension ServerTask {
	@ConveyActor func downloadFile(to destination: URL) async throws {
		try await handleThreadAndBackgrounding {
			var attemptCount = 1
			
			while true {
				do {
					let startedAt = Date()
					let request = try await beginRequest(at: startedAt)
					
					let session = await ConveySession(task: self)
					try await session.downloadFile(from: request, to: destination)
					
					try await postFlight()
				} catch {
					if let delay = (self.wrappedTask as? RetryableTask)?.retryInterval(after: error, attemptNumber: attemptCount) {
						attemptCount += 1
						try await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
					} else {
						throw error
					}
				}
			}
			
		}
	}
}
