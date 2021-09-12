//
//  Server.Remote.swift
//  Server.Remote
//
//  Created by Ben Gottlieb on 9/11/21.
//

import Foundation

public extension Server {
	struct Remote {
		public let name: String?
		public let url: URL
		public let shortName: String?
		
		public init(_ url: URL, name: String? = nil, shortName: String? = nil) {
			self.name = name
			self.shortName = shortName
			self.url = url
		}
	}
}
