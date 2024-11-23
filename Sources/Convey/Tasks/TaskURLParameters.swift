//
//  TaskURLParameters.swift
//  
//
//  Created by Ben Gottlieb on 1/5/24.
//

import Foundation

public protocol TaskURLParameters {
	var isEmpty: Bool { get }
	var parametersArray: [URLQueryItem] { get }
}

extension Dictionary: TaskURLParameters where Key == String, Value == String {
	public var parametersArray: [URLQueryItem] {
		[URLQueryItem](self)
	}
}
extension Array: TaskURLParameters where Element == URLQueryItem {
	init(_ dict: [String: String]) {
		self = dict.keys.map { URLQueryItem(name: $0, value: dict[$0]) }
	}
	
	public var parametersArray: [URLQueryItem] { self }
}

public func +(lhs: TaskURLParameters?, rhs: TaskURLParameters?) -> TaskURLParameters {
	var newHeaders = lhs?.parametersArray ?? []
	newHeaders.append(contentsOf: rhs?.parametersArray ?? [])
	return newHeaders
}
