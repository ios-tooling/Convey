//
//  ConveyServer.Remote.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/19/25.
//

import Foundation

public struct Remote: Identifiable, Hashable, Equatable, Codable, Sendable {
	public let name: String
	public let url: URL
	public var id: URL { url }
	public let shortName: String
	
	public static let empty = Remote(.empty, name: "Empty")
	
	public init(_ url: URL, name: String, shortName: String? = nil) {
		self.name = name
		self.url = url
		self.shortName = shortName ?? name
	}
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(url)
	}
	
	public static func == (lhs: Remote, rhs: Remote) -> Bool {
		lhs.url == rhs.url
	}
}
