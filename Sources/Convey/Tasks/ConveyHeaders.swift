//
//  ConveyHeaders.swift
//  Convey
//
//  Created by Ben Gottlieb on 10/1/24.
//

import Foundation

public struct ConveyHeader: Codable, Hashable, CustomStringConvertible, Sendable {
	public let name: String
	public let value: String
	public var description: String {
		"\(name): \(value)"
	}
}
public protocol ConveyHeaders {
	var headersArray: [ConveyHeader] { get }
}
extension [String: String]: ConveyHeaders { }
extension [ConveyHeader]: ConveyHeaders { }


extension [ConveyHeader] {
	init(_ dict: [String: String]) {
		self = dict.keys.map { ConveyHeader(name: $0, value: dict[$0]!) }
	}
	
	public var headersArray: [ConveyHeader] { self }
}

extension [String: String] {
	public var headersArray: [ConveyHeader] { [ConveyHeader](self) }
}

public func +(lhs: ConveyHeaders?, rhs: ConveyHeaders?) -> ConveyHeaders {
	var newHeaders = lhs?.headersArray ?? []
	newHeaders.append(contentsOf: rhs?.headersArray ?? [])
	return newHeaders
}
