//
//  Echoing.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/21/25.
//

import Foundation

public struct TaskEchoStyle: OptionSet, Sendable, Codable, Hashable {
	public let rawValue: Int
	public init(rawValue: Int) { self.rawValue = rawValue }
	
	public static let consoleMinimum = TaskEchoStyle(rawValue: 1 << 0)
	public static let consoleRequest = TaskEchoStyle(rawValue: 1 << 1)
	public static let consoleFull = TaskEchoStyle(rawValue: 1 << 2)
	public static let console5k = TaskEchoStyle(rawValue: 1 << 3)
	public static let console10k = TaskEchoStyle(rawValue: 1 << 4)
	public static let console30k = TaskEchoStyle(rawValue: 1 << 5)
	public static let console100k = TaskEchoStyle(rawValue: 1 << 6)
	
	public static let recorded = TaskEchoStyle(rawValue: 1 << 16)
	
	public static let onlyIfError = TaskEchoStyle(rawValue: 1 << 24)
}

//public enum TaskEchoStyle: Sendable, Codable, Hashable { case none, hidden, hiddenUnlessError, minimal, all, up, down, limit(UInt64?) }

public extension DownloadingTask {
	var echoStyle: TaskEchoStyle {
		if let style = configuration?.echoStyle { return style }
		if self is any NonEchoingTask { return [] }
		if self is any EchoingTask { return [.consoleFull, .recorded] }
		
		return [.recorded]
	}
	
	func echoStyle(for data: Data?) -> TaskEchoStyle { echoStyle }
	
	func echo(_ info: RequestTrackingInfo, data: Data?) {
		let style = echoStyle(for: data)
		if style.contains(.onlyIfError), info.error == nil { return }
		
		if style.contains(.consoleFull) {
			print(info.fullDescription)
		} else if style.contains(.console100k) {
			print(info.fullDescription(limit: 100 * 1024))
		} else if style.contains(.console30k) {
			print(info.fullDescription(limit: 30 * 1024))
		} else if style.contains(.console10k) {
			print(info.fullDescription(limit: 10 * 1024))
		} else if style.contains(.console5k) {
			print(info.fullDescription(limit: 5 * 1024))
		} else if style.contains(.consoleRequest) {
			print(info.request.debugDescription)
		} else if style.contains(.consoleMinimum) {
			print(info.minimalDescription)
		}
	}
}

public protocol EchoingTask: DownloadingTask { }
public protocol NonEchoingTask: DownloadingTask { }
