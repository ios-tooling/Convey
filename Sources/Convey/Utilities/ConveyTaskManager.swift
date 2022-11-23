//
//  ConveyTaskManager.swift
//  
//
//  Created by Ben Gottlieb on 6/18/22.
//

import Foundation

public extension ServerTask {
	static var shouldEcho: Bool {
		get { ConveyTaskManager.instance.shouldEcho(self) }
		set { ConveyTaskManager.instance.task(self, shouldEcho: newValue) }
	}
}

public class ConveyTaskManager: NSObject, ObservableObject {
	public static let instance = ConveyTaskManager()
	public var enabled = false { didSet { setup() }}
	public var directory = URL.systemDirectoryURL(which: .cachesDirectory)!.appendingPathComponent("convey_tasks")
	public var multitargetLogging = false
	public var storeResults = true
	public var shortLog = false

	let typesFilename = "convey_task_types.txt"
	var types: [TaskType] = [] {
		willSet { objectWillChange.send() }
		didSet { saveTypes() }
	}
	
	var typesURL: URL { directory.appendingPathComponent(typesFilename) }
	func validateDirectories() { try? FileManager.default.createDirectory(at: typesURL.deletingLastPathComponent(), withIntermediateDirectories: true) }

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
			Task {
				await loadTypes(resetting: true)
				if CommandLine.bool(for: "conveyShortLog") { shortLog = true }
				if let echos = CommandLine.string(for: "conveyEcho") ?? CommandLine.string(for: "conveyEchos") {
					print("Echoing: \(echos)")
					for type in echos.components(separatedBy: ",") {
						let trimmed = type.trimmingCharacters(in: .whitespacesAndNewlines)
						if trimmed.isEmpty { continue }
						setShouldEcho(taskType: trimmed)
					}
				}
			}
		}
	}
	
	func setShouldEcho(taskType: String, on: Bool = true) {
		if let index = index(of: taskType) {
			types[index].thisRunOnlyEcho = on
		} else {
			var newTask = TaskType(taskName: taskType)
			newTask.thisRunOnlyEcho = true
			types.append(newTask)
		}
	}
	
	func shouldEcho(_ task: ServerTask.Type) -> Bool {
		guard enabled, let index = index(of: task) else { return task.self is EchoingTask.Type }
		return types[index].shouldEcho
	}
	
	func task(_ task: ServerTask.Type, shouldEcho: Bool) {
		guard enabled else { return }
		
		if let index = index(of: task) {
			if shouldEcho {
				types[index].manuallyEcho = true
			} else {
				if types[index].compiledEcho || types[index].manuallyEcho == true || types[index].thisRunOnlyEcho {
					types[index].manuallyEcho = false
					types[index].thisRunOnlyEcho = false
				} else if !types[index].compiledEcho || types[index].manuallyEcho == false {
					types[index].manuallyEcho = nil
				}
			}
		} else {
			let name = String(describing: task.self)
			var newTask = TaskType(taskName: name)
			newTask.manuallyEcho = shouldEcho
			newTask.compiledEcho = task.self is EchoingTask.Type
			self.types.append(newTask)
		}
		objectWillChange.send()
	}
	
	func shouldEcho(_ task: ServerTask) -> Bool {
		guard enabled, let index = index(of: task) else { return task is EchoingTask }
		
		return types[index].shouldEcho
	}
	
	public func turnAllOff() {
		for i in types.indices {
			if types[i].name == "FetchUserProfile" {
				print("dddf")
			}

			if types[i].compiledEcho || types[i].manuallyEcho == true || types[i].thisRunOnlyEcho == true {
				types[i].manuallyEcho = false
			} else if !types[i].compiledEcho {
				types[i].manuallyEcho = nil
				types[i].thisRunOnlyEcho = false
			}
		}
		objectWillChange.send()
	}
	
	var areAllOff: Bool {
		types.filter { $0.shouldEcho }.isEmpty
	}
	
	public func resetAll() {
		for i in types.indices {
			types[i].totalCount = 0
			types[i].dates = []
			types[i].totalBytes = 0
			types[i].thisRunBytes = 0
			types[i].manuallyEcho = nil
			types[i].clearStoredFiles()
		}
		objectWillChange.send()
	}
	
	var canResetAll: Bool {
		for type in types {
			if type.manuallyEcho != nil { return true }
		}
		return false
	}

	func saveTypes() {
		validateDirectories()
		if let data = try? JSONEncoder().encode(types) {
			try? FileManager.default.removeItem(at: typesURL)
			try? data.write(to: typesURL)
		}
	}
	
	func loadTypes(resetting: Bool) async {
		guard let data = try? Data(contentsOf: typesURL) else { return }
		
		var newTypes = (try? JSONDecoder().decode([TaskType].self, from: data)) ?? []
		if resetting { newTypes.resetTaskTypes() }
		let filtered = newTypes
		await MainActor.run {
			types = filtered
		}
	}
	
	func index(of task: ServerTask.Type) -> Int? {
		let name = String(describing: task.self)
		return index(of: name)
	}
	
	func index(of taskName: String) -> Int? {
		return types.firstIndex(where: { $0.taskName == taskName })
	}
	
	func index(of task: ServerTask) -> Int? { index(of: type(of: task) ) }

	func begin(task: ServerTask, request: URLRequest, startedAt date: Date) async {
		if shortLog { print("☎️ \(task)")}
		if !enabled { return }
		if multitargetLogging { await loadTypes(resetting: false) }
		queue.async {
			let echo: Bool
			if let index = self.index(of: task) {
				self.types[index].dates.append(date)
				self.types[index].totalCount += 1
				echo = self.types[index].shouldEcho
			} else {
				let name = String(describing: type(of: task))
				var newTask = TaskType(taskName: name)
				newTask.compiledEcho = task is EchoingTask || task.server.echoAll
				echo = newTask.shouldEcho
				self.types.append(newTask)
			}
			if echo {
				print("🌐↑ \(type(of: task)): \(request)\n")
			}
			self.updateSort()
			if self.multitargetLogging { self.saveTypes() }
		}
	}
	
	func complete(task: ServerTask, request: URLRequest, response: HTTPURLResponse, bytes: Data, startedAt: Date, usingCache: Bool) async {
		if multitargetLogging { await loadTypes(resetting: false) }
		queue.async {
			if let index = self.index(of: task) {
				self.types[index].thisRunBytes += Int64(bytes.count)
				self.types[index].totalBytes += Int64(bytes.count)
				if self.multitargetLogging { self.saveTypes() }
				if self.types[index].shouldEcho {
					let log = task.loggingOutput(startedAt: startedAt, request: request, data: bytes, response: response)
					
					if usingCache {
						print("🌐⬇︎ \(type(of: task)): used cached response")
					} else {
						print("🌐⬇︎ \(type(of: task)) Response ======================\n \(String(data: log, encoding: .utf8) ?? "unable to stringify response")\n======================")
						if self.storeResults, response.didDownloadSuccessfully {
							self.types[index].store(results: log, from: startedAt) }
					}
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
		case .enabled: types.sort {
			if $0.shouldEcho, !$1.shouldEcho { return true }
			if $1.shouldEcho, !$0.shouldEcho { return false }
			return $0.taskName < $1.taskName
			}
		}
	}
}

extension ConveyTaskManager {
	enum Sort: String { case alpha, count, size, recent, enabled }
}

extension Array where Element == ConveyTaskManager.TaskType {
	mutating func resetTaskTypes() {
		for i in indices {
			self[i].dates = []
			self[i].thisRunBytes = 0
			self[i].clearStoredFiles()
		}
	}
}
