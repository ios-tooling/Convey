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
public protocol ConveyHeaders { }
extension [String: String]: ConveyHeaders { }
extension [ConveyHeader]: ConveyHeaders { }
