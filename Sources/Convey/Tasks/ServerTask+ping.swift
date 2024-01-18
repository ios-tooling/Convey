//
//  ServerTask+ping.swift
//
//
//  Created by Ben Gottlieb on 1/18/24.
//

import Foundation

extension ServerTask {
	public func ping() async throws -> TimeInterval {
		var request = try await self.buildRequest()
		request.httpMethod = "HEAD"
		let start = Date()
		let session = ConveySession(task: self)

		let _ = try await session.data(for: request)
		let duration = Date().timeIntervalSince(start)
		return duration
	}
}
