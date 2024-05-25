//
//  ServerTask+Echoing.swift
//  
//
//  Created by Ben Gottlieb on 5/16/22.
//

import Foundation
import Combine

public enum EchoStyle: String, Codable, Hashable, Sendable { case full, timing }

extension ServerTask {
	public var abbreviatedDescription: String {
		abbreviatedDescription(length: 100)
	}
	
	public func abbreviatedDescription(length: Int) -> String {
		let desc = "\(wrappedTask)"
		if desc.count < length { return desc }
		
		return desc.prefix(length / 2) + "…" + desc.suffix(length / 2 - 1)
	}
}

extension ServerTask {
	var isEchoing: Bool {
		get async {
			if let wrappedEcho { return wrappedEcho == .full }
			return await server.taskManager.shouldEcho(self)
		}
	}
}

public extension ServerTask {
	func logTiming(_ duration: TimeInterval) {
		print(String(format: "%@ took %.2fs", abbreviatedDescription, duration))
	}

	var taskTag: String {
		if let tag = (self.wrappedTask as? (any TaggedTask))?.requestTag { return tag }
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
