//
//  ConveyServer+Actions.swift
//  Convey
//
//  Created by Ben Gottlieb on 10/4/24.
//

import Combine
import Foundation

#if canImport(UIKit)
import UIKit

public extension ConveyServer {
	func recordTaskPath(to url: URL? = nil) {
		if let url {
			taskPath = .init(url: url)
		} else {
			if #available(iOS 16.0, macOS 13, watchOS 9, *) {
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
	
	func clearLogs() {
		if let dir = configuration.logDirectory { try? FileManager.default.removeItem(at: dir) }
	}
}

#endif

public extension ConveyServer {
	nonisolated func enableTaskLogging(style: ConveyTaskReporter.LogStyle? = .noLogging) {
		Task {
			await ConveyTaskReporter.instance.setLogStyle(style ?? .noLogging)
			await ConveyTaskReporter.instance.setEnabled(style != nil)
		}
	}
}
