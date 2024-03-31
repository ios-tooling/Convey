//
//  ServerTask+Echoing.swift
//  
//
//  Created by Ben Gottlieb on 5/16/22.
//

import Foundation
import Combine

extension ServerTask {
	var abbreviatedDescription: String {
		let desc = "\(self)"
		if desc.count < 100 { return desc }
		
		return desc.prefix(45) + "…" + desc.suffix(45)
	}
}

#if canImport(UIKit)
extension ServerTask {
	var isEchoing: Bool {
		get async { await server.taskManager.shouldEcho(self) }
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
