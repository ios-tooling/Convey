//
//  ServerTask+ping.swift
//
//
//  Created by Ben Gottlieb on 1/18/24.
//

import Foundation

extension ServerTask {
	@ConveyActor public func head() async throws -> [ConveyHeader] {
		var request = try await self.buildRequest()
		request.httpMethod = "HEAD"
		request.httpBody = nil
		
		let session = ConveySession(task: self)

		let result = try await session.data(for: request)

		return result.response.allHeaderFields.compactMap { k, v in
			guard let k = k as? String, let v = v as? String else { return nil }
			return ConveyHeader(name: k, value: v)
		}
	}
	
	public func ping() async throws -> TimeInterval {
		let start = Date()
		let _ = try await head()
		let duration = Date().timeIntervalSince(start)
		return duration
	}
}
