//
//  ConveyServer.Remote.swift
//  ConveyServer.Remote
//
//  Created by Ben Gottlieb on 9/11/21.
//

import Foundation

public extension ConveyServer {
	struct Remote: Identifiable, Hashable, Equatable {
		public let name: String?
		public let url: URL
		public let shortName: String?
		public var id: URL { url }
		public func hash(into hasher: inout Hasher) {
			hasher.combine(url)
		}
		public static func ==(lhs: Remote, rhs: Remote) -> Bool {
			lhs.url == rhs.url
		}

		public init(_ url: URL, name: String? = nil, shortName: String? = nil) {
			self.name = name
			self.shortName = shortName
			self.url = url
		}
	}
}
