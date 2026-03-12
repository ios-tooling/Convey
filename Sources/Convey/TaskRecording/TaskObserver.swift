//
//  TaskObserver.swift
//  Convey
//
//  Created by Ben Gottlieb on 3/12/26.
//

import SwiftUI

@available(iOS 17, macOS 14, watchOS 10, *)
@MainActor @Observable public class TaskObserver {
	public static let instance = TaskObserver()
	
	private var tasks: [ObservedTask] = []
	
	func didComplete<Target: DownloadingTask>(_ task: Target, payload: Target.DownloadPayload) {
		let type = type(of: task)
		for observed in tasks {
			if observed.type == type {
				observed.callback(task, payload, nil)
			}
		}
	}
	
	func didFail(_ task: any DownloadingTask, with error: any Error) {
		let type = type(of: task)
		for observed in tasks {
			if observed.type == type {
				observed.callback(task, nil, error)
			}
		}
	}
	
	struct ObservedTask {
		let id = UUID().uuidString
		let type: any DownloadingTask.Type
		let callback: @MainActor (any DownloadingTask, Any?, Error?) -> Void
		let filename: String
		let function: String
		let line: Int
		
		init<Target: DownloadingTask>(type: Target.Type, callback: @MainActor @escaping @Sendable (Target, Error?) -> Void, filename: String, function: String, line: Int) {
			self.type = type
			self.callback = { task, _, error in
				if let t2 = task as? Target {
					callback(t2, error)
				}
			}
			self.filename = filename
			self.function = function
			self.line = line
		}

		init<Target: DownloadingTask>(type: Target.Type, callback: @MainActor @escaping @Sendable (Target, Target.DownloadPayload?, Error?) -> Void, filename: String, function: String, line: Int) {
			self.type = type
			self.callback = { task, payload, error in
				if let t2 = task as? Target {
					if let p2 = payload as? Target.DownloadPayload {
						callback(t2, p2, error)
					} else {
						callback(t2, nil, error)
					}
				}
			}
			self.filename = filename
			self.function = function
			self.line = line
		}
	}
	
	public func register<Target: DownloadingTask>(_ task: Target.Type, filename: String = #file, function: String = #function, line: Int = #line, callback: @MainActor @escaping (Target, Error?) -> Void) -> String {
		let taskType = Target.self
		
		if let index = tasks.firstIndex(where: { $0.filename == filename && $0.function == function && $0.line == line }) {
			tasks[index] = ObservedTask(type: taskType, callback: callback, filename: filename, function: function, line: line)
			return tasks[index].id
		} else {
			let newTask = ObservedTask(type: taskType, callback: callback, filename: filename, function: function, line: line)
			tasks.append(newTask)
			return newTask.id
		}
	}
	
	public func register<Target: DownloadingTask>(_ task: Target.Type, filename: String = #file, function: String = #function, line: Int = #line, callback: @MainActor @escaping (Target, Target.DownloadPayload?, Error?) -> Void) -> String {
		let taskType = Target.self
		
		if let index = tasks.firstIndex(where: { $0.filename == filename && $0.function == function && $0.line == line }) {
			tasks[index] = ObservedTask(type: taskType, callback: callback, filename: filename, function: function, line: line)
			return tasks[index].id
		} else {
			let newTask = ObservedTask(type: taskType, callback: callback, filename: filename, function: function, line: line)
			tasks.append(newTask)
			return newTask.id
		}
	}
	
	public func unregister(token: String) {
		if let index = tasks.firstIndex(where: { $0.id == token }) {
			tasks.remove(at: index)
		}
	}
	
}
