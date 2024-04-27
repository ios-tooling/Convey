//
//  DownloadResponse.swift
//
//
//  Created by Ben Gottlieb on 4/27/24.
//

import Foundation

public struct DownloadResponse<Payload: Sendable>: Sendable {
	public init(payload: Payload, response: ServerReturned) {
		self.payload = payload
		self.response = response
	}
	
	public let payload: Payload
	public let response: ServerReturned
}

public struct ServerReturned: Sendable {
	public var response: HTTPURLResponse
	public var data: Data
	public var fromCache: Bool
	public var duration: TimeInterval?
	
	public var statusCode: Int { response.statusCode }
}
