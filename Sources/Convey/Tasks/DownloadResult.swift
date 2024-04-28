//
//  DownloadResponse.swift
//
//
//  Created by Ben Gottlieb on 4/27/24.
//

import Foundation

public struct DownloadResult<Payload: Sendable>: Sendable {
	public init(payload: Payload, response: ServerResponse) {
		self.payload = payload
		self.response = response
	}
	
	public let payload: Payload
	public let response: ServerResponse
	public var statusCode: Int { response.statusCode }
}

public struct ServerResponse: Sendable {
	public var response: HTTPURLResponse
	public var data: Data
	public var fromCache: Bool
	public var duration: TimeInterval?
	public var startedAt: Date
	
	public var statusCode: Int { response.statusCode }
}
