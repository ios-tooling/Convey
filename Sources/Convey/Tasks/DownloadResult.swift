//
//  DownloadResponse.swift
//
//
//  Created by Ben Gottlieb on 4/27/24.
//

import Foundation

@available(iOS, deprecated: 1, renamed: "ServerResponse", message: "ServerReturned has been renamed to ServerResponse")
public typealias ServerReturned = ServerResponse

public struct DownloadResult<Payload: Sendable>: Sendable {
    public init(payload: Payload, response: ServerResponse, retryCount: Int?, duration: TimeInterval) {
		self.payload = payload
		self.response = response
		self.retryCount = retryCount
        self.duration = duration
	}
	
	public let payload: Payload
	public let response: ServerResponse
	public var statusCode: Int { response.statusCode }
	public let retryCount: Int?
    public let duration: TimeInterval
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
