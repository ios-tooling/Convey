//
//  ServerSentEvent.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/10/26.
//

import Foundation

public struct ServerSentEvent: Sendable, Equatable {
	public let id: String?
	public let event: String?
	public let data: String
	public let retry: Int?

	public init(id: String? = nil, event: String? = nil, data: String, retry: Int? = nil) {
		self.id = id
		self.event = event
		self.data = data
		self.retry = retry
	}
}
