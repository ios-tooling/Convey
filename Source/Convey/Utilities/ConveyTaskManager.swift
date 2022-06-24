//
//  ConveyTaskManager.swift
//  
//
//  Created by Ben Gottlieb on 6/18/22.
//

import Foundation
import UIKit

public class ConveyTaskManager: NSObject, ObservableObject {
	public static let instance = ConveyTaskManager()
	public var enabled = false { didSet { setup() }}
	public var directory = URL.systemDirectoryURL(which: .cachesDirectory)!.appendingPathComponent("convey_tasks")
	public var multitargetLogging = false
	public var storeResults = true

	var sort = ConveyTaskManager.Sort.alpha { didSet {
		updateSort()
		objectWillChange.send()
	}}
	
	var queue = DispatchQueue(label: "ConveyTaskManager")
	private override init() {
		super.init()
		if !enabled { return }
		setup()
	}
	
	func setup() {
		if enabled {
			loadTypes(resetting: true)
		}
	}
	
	func shouldEcho(_ task: ServerTask) -> Bool {
		guard enabled, let index = index(of: task) else { return task is EchoingTask }
		
		return types[index].echo
	}
	
	public func resetAll() {
		for i in types.indices {
			types[i].totalCount = 0
			types[i].dates = []
			types[i].totalBytes = 0
			types[i].thisRunBytes = 0
			types[i].clearStoredFiles()
		}
		objectWillChange.send()
	}

	public func resetCurrent() {
		for i in types.indices {
			types[i].dates = []
			types[i].thisRunBytes = 0
			types[i].clearStoredFiles()
		}
		objectWillChange.send()
	}

	let typesFilename = "convey_task_types.txt"
	var types: [TaskType] = [] { didSet { saveTypes() }}
	
	var typesURL: URL { directory.appendingPathComponent(typesFilename) }
	func validateDirectories() { try? FileManager.default.createDirectory(at: typesURL.deletingLastPathComponent(), withIntermediateDirectories: true) }
	func saveTypes() {
		validateDirectories()
		if let data = try? JSONEncoder().encode(types) {
			try? data.write(to: typesURL)
		}
	}
	
	func loadTypes(resetting: Bool) {
		guard let data = try? Data(contentsOf: typesURL) else { return }
		
		types = (try? JSONDecoder().decode([TaskType].self, from: data)) ?? []
		if resetting { resetCurrent() }
	}
	
	func index(of task: ServerTask) -> Int? {
		let name = String(describing: type(of: task))
		return types.firstIndex(where: { $0.taskName == name })
	}
	
	func begin(task: ServerTask, request: URLRequest, startedAt date: Date) {
		if !enabled { return }
		if multitargetLogging { loadTypes(resetting: false) }
		queue.async {
			let echo: Bool
			if let index = self.index(of: task) {
				self.types[index].dates.append(date)
				self.types[index].totalCount += 1
				echo = self.types[index].echo
			} else {
				let name = String(describing: type(of: task))
				var newTask = TaskType(taskName: name)
				newTask.echo = task is EchoingTask
				echo = newTask.echo
				self.types.append(newTask)
			}
			if echo {
				print("🌐↑ \(type(of: task)): \(request)\n")
			}
			self.updateSort()
			if self.multitargetLogging { self.saveTypes() }
		}
	}
	
	func complete(task: ServerTask, request: URLRequest, response: URLResponse, bytes: Data, startedAt: Date) {
		if multitargetLogging { loadTypes(resetting: false) }
		queue.async {
			if let index = self.index(of: task) {
				self.types[index].thisRunBytes += Int64(bytes.count)
				self.types[index].totalBytes += Int64(bytes.count)
				if self.multitargetLogging { self.saveTypes() }
				if self.types[index].echo {
					let log = task.loggingOutput(startedAt: startedAt, request: request, data: bytes, response: response)
					print("🌐⬇︎ \(type(of: task)) Response ======================\n \(String(data: log, encoding: .utf8) ?? "unable to stringify response")\n======================")
					if self.storeResults {
						self.types[index].store(results: log, from: startedAt) }
				}
			}
		}
	}
	
	func updateSort() {
		switch sort {
		case .alpha: types.sort { $0.taskName < $1.taskName }
		case .count: types.sort { $0.thisRunCount > $1.thisRunCount }
		case .size: types.sort { $0.thisRunBytes > $1.thisRunBytes }
		case .recent: types.sort { ($0.mostRecent ?? .distantPast) > ($1.mostRecent ?? .distantPast) }
		}
	}
}

extension ConveyTaskManager {
	enum Sort: String { case alpha, count, size, recent }
}
