//
//  TaskInfo.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/21/25.
//

import Foundation

public struct TaskInfo: Sendable {
	let taskName: String
	let taskDescription: String
	
	var request: URLRequest?
	
	var data: Data?
	var response: URLResponse?
	
	init<T: DownloadingTask>(_ task: T) {
		taskName = String(describing: type(of: task))
		taskDescription = String(describing: task)
	}
}
