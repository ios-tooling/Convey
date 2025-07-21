//
//  Headers.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/19/25.
//

import Foundation

public struct Header: Codable, Hashable, CustomStringConvertible, Sendable {
	public let name: String
	public let value: String
	public var description: String {
		"\(name): \(value)"
	}
	public init(name: String, value: String) {
		self.name = name
		self.value = value
	}
}
public protocol Headers: Sendable {
	var headersArray: [Header] { get }
}
extension [String: String]: Headers { }
extension [Header]: Headers { }


extension [Header] {
	init(_ dict: [String: String]) {
		self = dict.keys.map { Header(name: $0, value: dict[$0]!) }
	}
	
	public var headersArray: [Header] { self }
}

extension [String: String] {
	public var headersArray: [Header] { [Header](self) }
}

public func +(lhs: Headers?, rhs: Headers?) -> Headers {
	var newHeaders = lhs?.headersArray ?? []
	newHeaders.append(contentsOf: rhs?.headersArray ?? [])
	return newHeaders
}
