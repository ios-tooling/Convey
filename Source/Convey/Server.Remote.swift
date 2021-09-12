//
//  Server.Remote.swift
//  Server.Remote
//
//  Created by Ben Gottlieb on 9/11/21.
//

import Foundation

public extension Server {
	struct Remote: Identifiable, Hashable {
		public let name: String?
		public let url: URL
		public let shortName: String?
		public var id: URL { url }
		public func hash(into hasher: inout Hasher) {
			hasher.combine(url)
		}

		public init(_ url: URL, name: String? = nil, shortName: String? = nil) {
			self.name = name
			self.shortName = shortName
			self.url = url
		}
	}
}
