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
	public var directory = URL.systemDirectoryURL(which: .cachesDirectory)!
	public var multitargetLogging = false
	
	var sort = ConveyTaskManager.Sort.alpha { didSet {
		updateSort()
		objectWillChange.send()
	}}
	
	private override init() {
		super.init()
		if !enabled { return }
		setup()
	}
	
	func setup() {
		if enabled {
			loadTypes(resetting: true)
			NotificationCenter.default.addObserver(self, selector: #selector(willResignActive), name: .init(rawValue: "UIApplicationWillResignActiveNotification"), object: nil)
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
			types[i].totalBytes = 0
			types[i].thisRunBytes = 0
		}
		objectWillChange.send()
	}

	public func resetCurrent() {
		for i in types.indices {
			types[i].thisRunCount = 0
			types[i].thisRunBytes = 0
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
	
	func begin(task: ServerTask) {
		if !enabled { return }
		if multitargetLogging { loadTypes(resetting: false) }
		if let index = index(of: task) {
			types[index].thisRunCount += 1
			types[index].totalCount += 1
		} else {
			let name = String(describing: type(of: task))
			var newTask = TaskType(taskName: name)
			newTask.echo = task is EchoingTask
			types.append(newTask)
		}
		updateSort()
		if multitargetLogging { saveTypes() }
	}
	
	func complete(task: ServerTask, bytes: Int) {
		if multitargetLogging { loadTypes(resetting: false) }
		if let index = index(of: task) {
			types[index].thisRunBytes += Int64(bytes)
			types[index].totalBytes += Int64(bytes)
			if multitargetLogging { saveTypes() }
		}
	}
	
	func updateSort() {
		switch sort {
		case .alpha: types.sort { $0.taskName < $1.taskName }
		case .count: types.sort { $0.thisRunCount > $1.thisRunCount }
		case .size: types.sort { $0.thisRunBytes > $1.thisRunBytes }
		}
	}
}

extension ConveyTaskManager {
	enum Sort: String { case alpha, count, size }
	struct TaskType: Codable, Equatable, Identifiable {
		var id: String { taskName }
		let taskName: String
		var totalCount = 1
		var thisRunCount = 1
		var totalBytes: Int64 = 0
		var thisRunBytes: Int64 = 0
		var echo = false
		
		var thisRunBytesString: String {
			ByteCountFormatter().string(fromByteCount: thisRunBytes)
		}
		
		var totalBytesString: String {
			ByteCountFormatter().string(fromByteCount: totalBytes)
		}
		
		var name: String {
			for suffix in ["Task", "Request"] {
				if taskName.hasSuffix(suffix) {
					return String(taskName.dropLast(suffix.count))
				}
			}
			return taskName
		}
	}
}
