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
		ConveyTaskManager.instance.shouldEcho(self)
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
		
		return "\(method) \(String(describing: type(of: self))).txt"
	}
}
