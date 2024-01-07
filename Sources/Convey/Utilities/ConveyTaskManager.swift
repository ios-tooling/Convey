//
//  ConveyTaskManager.swift
//  
//
//  Created by Ben Gottlieb on 6/18/22.
//

import Foundation

public extension ServerTask {
	static var shouldEcho: Bool {
		get { ConveyTaskManager.instance.shouldEcho(self as! ServerTask) }
		set { ConveyTaskManager.instance.task(self, shouldEcho: newValue) }
	}
}

public class ConveyTaskManager: NSObject, ObservableObject {
	public static let instance = ConveyTaskManager()
	public var enabled = false { didSet { setup() }}
	public var directory = URL.systemDirectoryURL(which: .cachesDirectory)!.appendingPathComponent("convey_tasks")
	public var multitargetLogging = false
	public var storeResults = true
	public var logStyle = LogStyle.none
	public var oneOffTypes: [String] = []
	public var recordings: [String: String] = [:]
	
	public enum LogStyle: String, Comparable, CaseIterable { case none, short, steps
		public static func <(lhs: Self, rhs: Self) -> Bool {
			Self.allCases.firstIndex(of: lhs)! < Self.allCases.firstIndex(of: rhs)!
		}
	}

	let typesFilename = "convey_task_types.txt"
	var types: [LoggedTaskInfo] = [] {
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
				if CommandLine.bool(for: "conveyShortLog") || ProcessInfo.bool(for: "conveyShortLog") { logStyle = .short }
				if let raw = CommandLine.string(for: "conveyLogStyle") ?? ProcessInfo.string(for: "conveyLogStyle") { logStyle = LogStyle(rawValue: raw) ?? .none }

				if let echos = CommandLine.string(for: "conveyEcho") ?? CommandLine.string(for: "conveyEchos") ?? ProcessInfo.string(for: "conveyEcho") ?? ProcessInfo.string(for: "conveyEchos") {
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
			var newTask = LoggedTaskInfo(taskName: taskType)
			newTask.thisRunOnlyEcho = true
			types.append(newTask)
		}
	}
	
	func incrementOneOffLog(for task: ServerTask) {
		enabled = true
		oneOffTypes.append(String(describing: type(of: task)))
	}

	func decrementOneOffLog(for task: ServerTask) {
		if let index = oneOffTypes.firstIndex(of: String(describing: type(of: task))) {
			oneOffTypes.remove(at: index)
		}
	}

	func shouldEcho(_ task: ServerTask.Type, isEchoing: Bool) -> Bool {
		guard enabled, let index = index(ofType: task, isEchoing: isEchoing) else { return task.self is EchoingTask.Type }
		return types[index].shouldEcho
	}
	
	func task(_ task: ServerTask.Type, shouldEcho: Bool) {
		guard enabled else { return }
		
		if let index = index(ofType: task, isEchoing: task is EchoingTask, noMatterWhat: true) {
			if shouldEcho {
				types[index].manuallyEcho = true
			} else {
				let compiledEcho = !types[index].suppressCompiledEcho && task is EchoingTask
				if compiledEcho || types[index].manuallyEcho == true || types[index].thisRunOnlyEcho {
					types[index].manuallyEcho = false
					types[index].thisRunOnlyEcho = false
				} else if !compiledEcho || types[index].manuallyEcho == false {
					types[index].manuallyEcho = nil
				}
			}
		}
		objectWillChange.send()
	}
	
	func record(_ string: String, for task: ServerTask) {
		let tag = task.taskTag
		let current = recordings[tag] ?? ""
		
		recordings[tag] = current + string
	}
	
	func dumpRecording(for task: ServerTask) {
		task.server.pathCount += 1
		let tag = task.taskTag
		guard let recording = recordings[tag] else { return }
		
		if task.isEchoing { print(recording) }
		if let pathURL = task.server.taskPathURL {
			let filename = String(format: "%02d", task.server.pathCount) + ". " + tag.filename
			let url = pathURL.appendingPathComponent(filename + ".txt")
			try? recording.write(to: url, atomically: true, encoding: .utf8)
		}
		recordings.removeValue(forKey: tag)
	}
	
	func shouldEcho(_ task: ServerTask) -> Bool {
		guard enabled, let index = index(of: task) else { return task is EchoingTask }
		
		return types[index].shouldEcho
	}
	
	public func turnAllOff() {
		for i in types.indices {
			if types[i].manuallyEcho == true || types[i].thisRunOnlyEcho == true {
				types[i].manuallyEcho = false
				types[i].suppressCompiledEcho = true
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
		
		var newTypes = (try? JSONDecoder().decode([LoggedTaskInfo].self, from: data)) ?? []
		if resetting { newTypes.resetTaskTypes() }
		let filtered = newTypes
		await MainActor.run {
			types = filtered
		}
	}
	
	func index(ofType task: ServerTask.Type, isEchoing: Bool, noMatterWhat: Bool = false) -> Int? {
		let name = String(describing: task.self)
		if let index = index(of: name) { 
			types[index].compiledEcho = isEchoing
			return index
		}
		
		if !noMatterWhat { return nil }
		var newTask = LoggedTaskInfo(taskName: name)
		newTask.compiledEcho = task is EchoingTask
		self.types.append(newTask)
		return self.types.count - 1
	}
	
	func index(of taskName: String) -> Int? {
		return types.firstIndex(where: { $0.taskName == taskName })
	}
	
	func index(of task: ServerTask) -> Int? { index(ofType: type(of: task), isEchoing: task is EchoingTask) }

	func begin(task: ServerTask, request: URLRequest, startedAt date: Date) async {
		if !enabled { return }
		if logStyle > .none { print("☎️ Begin \(task)")}
		if multitargetLogging { await loadTypes(resetting: false) }
		queue.async {
			let echo: Bool
			if let index = self.index(of: task) {
				self.types[index].dates.append(date)
				self.types[index].totalCount += 1
				echo = self.types[index].shouldEcho
			} else {
				let name = String(describing: type(of: task))
				var newTask = LoggedTaskInfo(taskName: name)
				newTask.compiledEcho = task is EchoingTask
				echo = newTask.shouldEcho
				self.types.append(newTask)
			}
			if echo || task.server.shouldRecordTaskPath{
				self.record("\(type(of: task)): \(request)\n", for: task)
			}
			self.updateSort()
			if self.multitargetLogging { self.saveTypes() }
		}
	}
	
	func complete(task: ServerTask, request: URLRequest, response: HTTPURLResponse, bytes: Data, startedAt: Date, usingCache: Bool) async {
		let shouldEcho: Bool
		
		if let index = self.index(of: task) {
			shouldEcho = self.types[index].shouldEcho
		} else {
			shouldEcho = false
		}
		if multitargetLogging { await loadTypes(resetting: false) }
		if logStyle > .short { print("☎︎ End \(task)")}
		queue.async {
			let index = self.index(of: task)
			if let index {
				self.types[index].thisRunBytes += Int64(bytes.count)
				self.types[index].totalBytes += Int64(bytes.count)
				if self.multitargetLogging { self.saveTypes() }
			}
			if shouldEcho || task.server.shouldRecordTaskPath {
				let log = task.loggingOutput(startedAt: startedAt, request: request, data: bytes, response: response)
				
				if usingCache {
					self.record("\(type(of: task)): used cached response", for: task)
				} else {
					self.record("\(type(of: task)) Response ======================\n \(String(data: log, encoding: .utf8) ?? "unable to stringify response")\n======================", for: task)
					if self.storeResults, response.didDownloadSuccessfully, let index {
						self.types[index].store(results: log, from: startedAt) }
				}
				
				self.dumpRecording(for: task)
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

extension Array where Element == ConveyTaskManager.LoggedTaskInfo {
	mutating func resetTaskTypes() {
		for i in indices {
			self[i].dates = []
			self[i].thisRunBytes = 0
			self[i].clearStoredFiles()
		}
	}
}
