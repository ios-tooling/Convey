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
	public var enabled = true { didSet { setup() }}
	public var directory = URL.systemDirectoryURL(which: .cachesDirectory)!
	
	private override init() {
		super.init()
		if !enabled { return }
		setup()
	}
	
	func setup() {
		if enabled {
			loadTypes()
			NotificationCenter.default.addObserver(self, selector: #selector(willResignActive), name: UIApplication.willResignActiveNotification, object: nil)
		}
	}
	
	func shouldEcho(_ task: ServerTask) -> Bool {
		guard enabled, let index = index(of: task) else { return task is EchoingTask }
		
		return types[index].echo
	}
	
	@objc func willResignActive() {
		saveTypes()
	}
	
	public func resetAll() {
		for i in types.indices {
			types[i].totalCount = 0
			types[i].thisRunCount = 0
		}
		objectWillChange.send()
	}

	public func resetCurrent() {
		for i in types.indices {
			types[i].thisRunCount = 0
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
	
	func loadTypes() {
		guard let data = try? Data(contentsOf: typesURL) else { return }
		
		types = (try? JSONDecoder().decode([TaskType].self, from: data)) ?? []
		resetCurrent()
	}
	
	func index(of task: ServerTask) -> Int? {
		let name = String(describing: type(of: task))
		return types.firstIndex(where: { $0.taskName == name })
	}
	
	func record(task: ServerTask) {
		if !enabled { return }
		if let index = index(of: task) {
			types[index].thisRunCount += 1
			types[index].totalCount += 1
		} else {
			let name = String(describing: type(of: task))
			var newTask = TaskType(taskName: name)
			newTask.echo = task is EchoingTask
			types.append(newTask)
		}
		objectWillChange.send()
	}
	
	struct TaskType: Codable, Equatable, Identifiable {
		var id: String { taskName }
		let taskName: String
		var totalCount = 1
		var thisRunCount = 1
		var echo = false
	}
}
