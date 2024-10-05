//
//  URLQueryItem.swift
//  
//
//  Created by Ben Gottlieb on 10/9/22.
//

import Foundation

public extension Array where Element == URLQueryItem {
	func contains(name: String) -> Bool {
		contains { $0.name == name }
	}
	
	mutating func replaceFirst(name: String, with value: String) {
		if let index = firstIndex(where: { $0.name == name }) {
			self[index] = URLQueryItem(name: name, value: value)
		} else {
			self.append(name: name, value: value)
		}
	}
	
	mutating func append(name: String, value: String) {
		self.append(URLQueryItem(name: name, value: value))
	}
}
