//
//  Echoing.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/21/25.
//

import Foundation

public enum TaskEchoStyle { case none, minimal, all, up, down }

public extension DownloadingTask {
	var echoStyle: TaskEchoStyle {
		if self is any NonEchoingTask { return .none }
		if self is any EchoingTask { return .all }
		
		return .none
	}
	
	func echo(_ info: RequestTrackingInfo) {
		switch echoStyle {
		case .none: break
			
		case .minimal:
			print(info.minimalDescription)
		case .all:
			print(info.fullDescription)
		case .up:
			print(info.minimalDescription)
		case .down:
			print(info.minimalDescription)
		}
	}
}

public protocol EchoingTask: DownloadingTask { }
public protocol NonEchoingTask: DownloadingTask { }
