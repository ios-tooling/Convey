//
//  TaskQueryParameters.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/19/25.
//

import Foundation

public protocol TaskQueryParameters: Sendable, Hashable, Equatable {
	var isEmpty: Bool { get }
	var parametersArray: [URLQueryItem] { get }
}

extension Dictionary: TaskQueryParameters where Key == String, Value == String {
	public var parametersArray: [URLQueryItem] {
		[URLQueryItem](self)
	}
}
extension [URLQueryItem]: TaskQueryParameters {
	init(_ dict: [String: String]) {
		self = dict.keys.map { URLQueryItem(name: $0, value: dict[$0]) }
	}
	
	public var parametersArray: [URLQueryItem] { self }
}

public func +(lhs: (any TaskQueryParameters)?, rhs: (any TaskQueryParameters)?) -> any TaskQueryParameters {
	var newHeaders = lhs?.parametersArray ?? []
	newHeaders.append(contentsOf: rhs?.parametersArray ?? [])
	return newHeaders
}
