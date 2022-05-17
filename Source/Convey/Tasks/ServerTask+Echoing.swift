//
//  ServerTask+Echoing.swift
//  
//
//  Created by Ben Gottlieb on 5/16/22.
//

import Foundation

var echoingTypeNames: [String] = []

extension ServerTask {
	var isEchoing: Bool {
		if self is EchoingTask { return true }
		
		let typeName = "\(type(of: self))"
		return echoingTypeNames.contains(typeName)
	}

	static func echoes() {
		let typeName = "\(self)"
		if !echoingTypeNames.contains(typeName) {
			echoingTypeNames.append(typeName)
		}
	}

}
