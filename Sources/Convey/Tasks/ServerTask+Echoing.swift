//
//  ServerTask+Echoing.swift
//  
//
//  Created by Ben Gottlieb on 5/16/22.
//

import Foundation

#if canImport(UIKit)
var echoingTypeNames: [String] = []

extension ServerTask {
	var isEchoing: Bool {
		server.taskManager.shouldEcho(self)
	}
}
#else

extension ServerTask {
	var isEchoing: Bool {
		true
	}
}

#endif

public extension ServerTask {
	var taskTag: String {
		if let tag = (self as? (any TaggedTask))?.requestTag { return tag }
		return String(describing: self)
	}
	
	var filename: String {
		let method = httpMethod
		var name = String(describing: type(of: self))
		
		if name.lowercased().hasPrefix(method.lowercased()) {
			name = String(name.dropFirst(method.count))
		}
		
		if name.lowercased().hasSuffix("task") {
			name = String(name.dropLast(4))
		}
		
		return "\(method) \(name).txt"
	}
}
