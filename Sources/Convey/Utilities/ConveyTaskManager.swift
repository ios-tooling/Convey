//
//  ConveyTaskManager.swift
//  
//
//  Created by Ben Gottlieb on 6/18/22.
//

import Combine
import Foundation

public extension ServerTask {
	static var shouldEcho: Bool {
		get async { await ConveyServer.serverInstance.taskManager.shouldEcho(self as! ServerTask) }
	}
	
	static func setShouldEcho(_ shouldEcho: Bool) async {
		await ConveyServer.serverInstance.taskManager.task(self, shouldEcho: shouldEcho)
	}
}

public actor ConveyTaskManager: NSObject, ObservableObject {
	public var enabled = false { didSet { setup() }}
	public nonisolated var directory: URL {
		get { directoryValue.value }
		set { directoryValue.value = newValue }
	}
	let directoryValue: CurrentValueSubject<URL, Never> = .init(URL.systemDirectoryURL(which: .cachesDirectory)!.appendingPathComponent("convey_tasks"))
	public var multitargetLogging = false
	public var storeResults = true
	public var logStyle = LogStyle.none
	let oneOffTypes: CurrentValueSubject<[String], Never> = .init([])
	public var recordings: [String: String] = [:]
	unowned var server: ConveyServer
	
	public enum LogStyle: String, Comparable, CaseIterable, Sendable { case none, short, steps
		public static func <(lhs: Self, rhs: Self) -> Bool {
			Self.allCases.firstIndex(of: lhs)! < Self.allCases.firstIndex(of: rhs)!
		}
	}

	let typesFilename: String
	let types: CurrentValueSubject<[LoggedTaskInfo], Never> = .init([])
	nonisolated var sortedTypes: [LoggedTaskInfo] { types.value }
	func saveTypes(_ types: [LoggedTaskInfo]? = nil) {
		if let types { self.types.value = types }
		
		validateDirectories()
		if let data = try? JSONEncoder().encode(self.types.value) {
			try? FileManager.default.removeItem(at: typesURL)
			try? data.write(to: typesURL)
		}

		DispatchQueue.main.async { self.objectWillChange.send() }
	}
	
	var typesURL: URL { directory.appendingPathComponent(typesFilename) }
	func validateDirectories() { try? FileManager.default.createDirectory(at: typesURL.deletingLastPathComponent(), withIntermediateDirectories: true) }

	let sort: CurrentValueSubject<ConveyTaskManager.Sort, Never> = .init(.alpha)
	
	var queue = DispatchQueue(label: "ConveyTaskManager")
	init(for server: ConveyServer) {
		typesFilename = "convey_task_types_\(String(describing: type(of: server))).txt"
		self.server = server
		super.init()
		if !enabled { return }
		Task { await setup() }
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
			types.value[index].thisRunOnlyEcho = on
		} else {
			var newTask = LoggedTaskInfo(taskName: taskType)
			newTask.thisRunOnlyEcho = true
			types.value.append(newTask)
		}
		saveTypes()
	}
	
	func incrementOneOffLog(for task: ServerTask) {
		enabled = true
		oneOffTypes.value.append(String(describing: type(of: task)))
	}

	func decrementOneOffLog(for task: ServerTask) {
		if let index = oneOffTypes.value.firstIndex(of: String(describing: type(of: task))) {
			oneOffTypes.value.remove(at: index)
		}
	}

	func shouldEcho(_ task: ServerTask.Type, isEchoing: Bool) -> Bool {
		guard enabled, let index = index(ofType: task, isEchoing: isEchoing) else { return task.self is EchoingTask.Type }
		return types.value[index].shouldEcho(task, for: self)
	}
	
	func task(_ task: ServerTask.Type, shouldEcho: Bool) {
		guard enabled else { return }
		
		var insideTypes = types.value
		
		if let index = index(ofType: task, isEchoing: task is EchoingTask, noMatterWhat: true) {
			if shouldEcho {
				insideTypes[index].manuallyEcho = true
			} else {
				let compiledEcho = !insideTypes[index].suppressCompiledEcho && task is EchoingTask
				if compiledEcho || insideTypes[index].manuallyEcho == true || insideTypes[index].thisRunOnlyEcho {
					insideTypes[index].manuallyEcho = false
					insideTypes[index].thisRunOnlyEcho = false
				} else if !compiledEcho || insideTypes[index].manuallyEcho == false {
					insideTypes[index].manuallyEcho = nil
				}
			}
		}
		saveTypes(insideTypes)
	}
	
	func record(_ string: String, for task: ServerTask) {
		let tag = task.taskTag
		let current = recordings[tag] ?? ""
		
		recordings[tag] = current + string
	}
	
	func dumpRecording(for task: ServerTask) async {
		task.server.pathCount += 1
		let tag = task.taskTag
		guard let recording = recordings[tag] else { return }
		
		if await task.isEchoing { print(recording) }
		if let pathURL = task.server.taskPathURL {
			let filename = String(format: "%02d", task.server.pathCount) + ". " + task.filename
			let url = pathURL.appendingPathComponent(filename)
			try? recording.write(to: url, atomically: true, encoding: .utf8)
		}
		recordings.removeValue(forKey: tag)
	}
	
	func shouldEcho(_ task: ServerTask) -> Bool {
		guard enabled, let index = index(of: task) else { return task is EchoingTask }
		
		return types.value[index].shouldEcho(type(of: task), for: self)
	}
	
	public nonisolated func turnAllOff() {
		for i in types.value.indices {
			if types.value[i].manuallyEcho == true || types.value[i].thisRunOnlyEcho == true {
				types.value[i].manuallyEcho = false
				types.value[i].suppressCompiledEcho = true
			} else if !types.value[i].compiledEcho {
				types.value[i].manuallyEcho = nil
				types.value[i].thisRunOnlyEcho = false
			}
		}
		objectWillChange.send()
	}
	
	nonisolated var areAllOff: Bool {
		types.value.filter { $0.shouldEcho(for: self) }.isEmpty
	}
	
	public nonisolated func resetAll() {
		var insideTypes = types.value
		
		for i in insideTypes.indices {
			insideTypes[i].totalCount = 0
			insideTypes[i].dates = []
			insideTypes[i].totalBytes = 0
			insideTypes[i].thisRunBytes = 0
			insideTypes[i].manuallyEcho = nil
			insideTypes[i].clearStoredFiles(for: self)
		}
		
		let saveThis = insideTypes
		Task { await saveTypes(saveThis) }
	}
	
	nonisolated var canResetAll: Bool {
		for type in types.value {
			if type.manuallyEcho != nil { return true }
		}
		return false
	}
	
	func loadTypes(resetting: Bool) async {
		guard let data = try? Data(contentsOf: typesURL) else { return }
		
		var newTypes = (try? JSONDecoder().decode([LoggedTaskInfo].self, from: data)) ?? []
		if resetting { newTypes.resetTaskTypes(for: self) }
		let filtered = newTypes
		types.value = filtered
	}
	
	func index(ofType task: ServerTask.Type, isEchoing: Bool, noMatterWhat: Bool = false) -> Int? {
		let name = String(describing: task.self)
		if let index = index(of: name) { 
			types.value[index].compiledEcho = isEchoing
			return index
		}
		
		if !noMatterWhat { return nil }
		var newTask = LoggedTaskInfo(taskName: name)
		newTask.compiledEcho = task is EchoingTask
		self.types.value.append(newTask)
		return self.types.value.count - 1
	}
	
	func index(of taskName: String) -> Int? {
		return types.value.firstIndex(where: { $0.taskName == taskName })
	}
	
	func index(of task: ServerTask) -> Int? { index(ofType: type(of: task), isEchoing: task is EchoingTask) }

	func begin(task: ServerTask, request: URLRequest, startedAt date: Date) async {
		if !enabled { return }
		if await task.server.effectiveLogStyle > .none { print("☎️ Begin \(task.abbreviatedDescription)") }
		if multitargetLogging { await loadTypes(resetting: false) }

		let echo: Bool

		if let index = self.index(of: task) {
			self.types.value[index].dates.append(date)
			self.types.value[index].totalCount += 1
			echo = self.types.value[index].shouldEcho(type(of: task), for: self)
		} else {
			let name = String(describing: type(of: task))
			var newTask = LoggedTaskInfo(taskName: name)
			newTask.compiledEcho = task is EchoingTask
			echo = newTask.shouldEcho(type(of: task), for: self)
			self.types.value.append(newTask)
		}

		if echo || task.server.shouldRecordTaskPath{
			self.record("\(type(of: task)): \(request)\n", for: task)
		}
		self.updateSort()
		if self.multitargetLogging { self.saveTypes() }
	}
	
	func complete(task: ServerTask, request: URLRequest, response: HTTPURLResponse, bytes: Data, startedAt: Date, usingCache: Bool) async {
		let shouldEcho: Bool
		
		if let index = self.index(of: task) {
			shouldEcho = self.types.value[index].shouldEcho(type(of: task), for: self)
		} else {
			shouldEcho = false
		}
		if multitargetLogging { await loadTypes(resetting: false) }
		if await task.server.effectiveLogStyle > .short { print("☎︎ End \(task.abbreviatedDescription)")}

	let index = self.index(of: task)
		if let index {
			self.types.value[index].thisRunBytes += Int64(bytes.count)
			self.types.value[index].totalBytes += Int64(bytes.count)
			if self.multitargetLogging { self.saveTypes() }
		}
		if shouldEcho || task.server.shouldRecordTaskPath {
			let log = task.loggingOutput(startedAt: startedAt, request: request, data: bytes, response: response)
			
			if usingCache {
				self.record("\(type(of: task)): used cached response", for: task)
			} else {
				self.record("\(type(of: task)) Response ======================\n \(String(data: log, encoding: .utf8) ?? String(data: log, encoding: .ascii) ?? "unable to stringify response")\n======================", for: task)
				if self.storeResults, response.didDownloadSuccessfully, let index {
					self.types.value[index].store(results: log, from: startedAt, for: self) }
			}
			
			await self.dumpRecording(for: task)
		}
	}
	
	func updateSort(by: ConveyTaskManager.Sort? = nil) {
		let sort = by ?? self.sort.value
		self.sort.value = sort
		var insideTypes = types.value
		
		switch sort {
		case .alpha: insideTypes.sort { $0.taskName < $1.taskName }
		case .count: insideTypes.sort { $0.thisRunCount > $1.thisRunCount }
		case .size: insideTypes.sort { $0.thisRunBytes > $1.thisRunBytes }
		case .recent: insideTypes.sort { ($0.mostRecent ?? .distantPast) > ($1.mostRecent ?? .distantPast) }
		case .enabled: insideTypes.sort {
			if $0.shouldEcho(for: self), !$1.shouldEcho(for: self) { return true }
			if $1.shouldEcho(for: self), !$0.shouldEcho(for: self) { return false }
			return $0.taskName < $1.taskName
			}
		}
		saveTypes(insideTypes)
	}
}

extension ConveyTaskManager {
	enum Sort: String, Sendable { case alpha, count, size, recent, enabled }
}

extension Array where Element == ConveyTaskManager.LoggedTaskInfo {
	mutating func resetTaskTypes(for manager: ConveyTaskManager) {
		for i in indices {
			self[i].dates = []
			self[i].thisRunBytes = 0
			self[i].clearStoredFiles(for: manager)
		}
	}
}
