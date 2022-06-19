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
		ConveyTaskManager.instance.shouldEcho(self)
	}

}
