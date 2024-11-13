//
//  DownloadResponse.swift
//
//
//  Created by Ben Gottlieb on 4/27/24.
//

import Foundation

@available(iOS, deprecated: 1, renamed: "ServerResponse", message: "ServerReturned has been renamed to ServerResponse")
public typealias ServerReturned = ServerResponse

public struct PayloadServerResponse<Payload: Sendable>: Sendable {
	public init(payload: Payload, response: ServerResponse) {
		self.payload = payload
		self.response = response.response
		self.data = response.data
		self.startedAt = response.startedAt
		self.fromCache = response.fromCache
		self.retryCount = response.retryCount
		self.duration = response.duration
		self.serverResponse = response
	}
	
	public let payload: Payload
	public var statusCode: Int { response.statusCode }
	public let retryCount: Int?
	public let duration: TimeInterval
	public let serverResponse: ServerResponse
	
	public let response: HTTPURLResponse
	public let data: Data
	public let fromCache: Bool
	public let startedAt: Date
}

public struct ServerResponse: Sendable {
	public var response: HTTPURLResponse
	public var data: Data
	public var fromCache: Bool
	public var duration: TimeInterval
	public var startedAt: Date
	public var retryCount: Int?
	
	public var statusCode: Int { response.statusCode }
	
	func withRetryCount(_ count: Int) -> Self {
		var result = self
		result.retryCount = count
		return result
	}
}
