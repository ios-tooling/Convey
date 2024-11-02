//
//  ConveyServer+Actions.swift
//  Convey
//
//  Created by Ben Gottlieb on 10/4/24.
//

#if canImport(UIKit)
import Combine
import UIKit

public extension ConveyServer {
	func recordTaskPath(to url: URL? = nil) {
		if let url {
			taskPath = .init(url: url)
		} else {
			if #available(iOS 16.0, macOS 13, *) {
				taskPath = .init()
			}
		}
		objectWillChange.send()
	}
	
	func endTaskPathRecording() {
		self.taskPath?.stop()
		self.taskPath = nil
		objectWillChange.send()
	}
	
	func register(publicKey: String, for server: String) {
		var keys = pinnedServerKeys[server, default: []]
		keys.append(publicKey)
		pinnedServerKeys[server] = keys
	}
	
	func clearLogs() {
		if let dir = configuration.logDirectory { try? FileManager.default.removeItem(at: dir) }
	}
}

#endif
