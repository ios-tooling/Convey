//
//  ConveyTaskReporter.swift
//  
//
//  Created by Ben Gottlieb on 6/18/22.
//

import Combine
import Foundation
import OSLog

public extension ServerTask {
	static var shouldEcho: Bool {
		get async { ConveyTaskReporter.instance.shouldEcho(self as! ServerTask) }
	}
	
	static func setShouldEcho(_ shouldEcho: Bool) async {
		ConveyTaskReporter.instance.task(self, shouldEcho: shouldEcho)
	}
}

@MainActor class TaskReporterObserver: ObservableObject {
	var cancellable: AnyCancellable?
	
	init() {
		Task {
			cancellable = await ConveyTaskReporter.instance.objectWillChange
				.receive(on: RunLoop.main)
				.sink {
					self.objectWillChange.send()
				}
		}
	}
}

@ConveyActor public class ConveyTaskReporter: ObservableObject {
	public static let instance = ConveyTaskReporter()
	
	public var enabled = false { didSet { setup() }}
	public nonisolated var directory: URL {
		get { directoryValue.value }
		set { directoryValue.value = newValue }
	}
	
	public func setEnabled(_ enabled: Bool = true) {
		self.enabled = enabled
	}

	public nonisolated func setIsEnabled(_ enabled: Bool = true) {
		Task { await setEnabled(enabled) }
	}

	public nonisolated func setLoggingStyle(_ logStyle: LogStyle) {
		Task { await setLogStyle(logStyle) }
	}
	
	public func setLogStyle(_ logStyle: LogStyle) {
		self.logStyle = logStyle
	}
	
	let directoryValue: CurrentValueSubject<URL, Never> = .init(URL.systemDirectoryURL(which: .cachesDirectory)!.appendingPathComponent("convey_tasks"))
	public var multitargetLogging = false
	public var storeResults = true
	public var logStyle = LogStyle.none
	let oneOffTypes: CurrentValueSubject<[String], Never> = .init([])
	public var recordings: [String: RecordedTask] = [:]
	
	public enum LogStyle: String, Comparable, CaseIterable, Sendable { case none, short, steps
		public static func <(lhs: Self, rhs: Self) -> Bool {
			Self.allCases.firstIndex(of: lhs)! < Self.allCases.firstIndex(of: rhs)!
		}
	}

	let typesFilename: String
	let types: CurrentValueSubject<[LoggedTaskInfo], Never> = .init([])
	nonisolated var sortedTypes: [LoggedTaskInfo] {
		get { types.value }
		set { types.value = newValue }
	}
	
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

	nonisolated let sort: CurrentValueSubject<ConveyTaskReporter.Sort, Never> = .init(.alpha)
	
	var queue = DispatchQueue(label: "ConveyTaskReporter")
	init() {
		typesFilename = "convey_task_types.txt"
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
		oneOffTypes.value.append(String(describing: type(of: task.wrappedTask)))
	}

	func decrementOneOffLog(for task: ServerTask) {
		if let index = oneOffTypes.value.firstIndex(of: String(describing: type(of: task.wrappedTask))) {
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

	func record(startedAt: Date? = nil, completedAt: Date? = nil, request: URLRequest? = nil, response: Data? = nil, cachedResponse: Data? = nil, for task: ServerTask) {
		let tag = task.taskTag
		var current = recordings[tag] ?? .init(task: task)
		
		if let startedAt { current.startedAt = startedAt }
		if let completedAt { current.completedAt = completedAt }
		if let request { current.request = request }
		if let response { current.download = response }
		if let cachedResponse { current.cachedResponse = cachedResponse }
		recordings[tag] = current
	}
	
	func record(_ string: String, for task: ServerTask) {
		let tag = task.taskTag
		var current = recordings[tag] ?? .init(task: task)
		
		current.recording = current.recording + string
		recordings[tag] = current
	}
	
	func dumpRecording(for task: ServerTask) async {
		let tag = task.taskTag
		guard let recording = recordings[tag] else { return }
		
		if await task.isEchoing { recording.echo() }
		await task.server.taskPath?.save(task: recording)
		recordings.removeValue(forKey: tag)
	}
	
	func shouldEcho(_ task: ServerTask) -> Bool {
		guard enabled, let index = index(of: task) else { return task.wrappedTask is EchoingTask }
		
		return types.value[index].shouldEcho(type(of: task.wrappedTask), for: self)
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
	
	func index(of task: ServerTask) -> Int? { index(ofType: type(of: task.wrappedTask), isEchoing: task.wrappedTask is EchoingTask) }

	func begin(task: ServerTask, request: URLRequest, startedAt date: Date) async {
		if !enabled { return }
		if ConveyTaskReporter.instance.logStyle > .none, !(task is DisabledShortEchoTask) { print("☎️ Begin \(task.abbreviatedDescription)") }
		if multitargetLogging { await loadTypes(resetting: false) }

		let echo: Bool

		if task.wrappedEcho == .full {
			echo = true
		} else if let index = self.index(of: task.wrappedTask) {
			self.types.value[index].dates.append(date)
			self.types.value[index].totalCount += 1
			echo = self.types.value[index].shouldEcho(type(of: task.wrappedTask), for: self)
		} else {
			let name = String(describing: type(of: task.wrappedTask))
			var newTask = LoggedTaskInfo(taskName: name)
			newTask.compiledEcho = task.wrappedTask.wrappedTask is EchoingTask
			echo = newTask.shouldEcho(type(of: task.wrappedTask), for: self)
			self.types.value.append(newTask)
		}

		if echo || task.server.shouldRecordTaskPath {
			self.record(startedAt: date, request: request, for: task)
		}
		self.updateSort()
		if self.multitargetLogging { self.saveTypes() }
	}
	
	func complete(task: ServerTask, request: URLRequest, response: HTTPURLResponse, bytes: Data, startedAt: Date, usingCache: Bool) async {
		let shouldEcho: Bool
		
		if task.wrappedEcho == .full {
			shouldEcho = true
		} else if let index = self.index(of: task) {
			shouldEcho = self.types.value[index].shouldEcho(type(of: task.wrappedTask), for: self)
		} else {
			shouldEcho = false
		}
		if multitargetLogging { await loadTypes(resetting: false) }
		if ConveyTaskReporter.instance.logStyle > .short { print("☎︎ End \(task.abbreviatedDescription)")}

	let index = self.index(of: task)
		if let index {
			self.types.value[index].thisRunBytes += Int64(bytes.count)
			self.types.value[index].totalBytes += Int64(bytes.count)
			if self.multitargetLogging { self.saveTypes() }
		}
		if shouldEcho || task.server.shouldRecordTaskPath {
			let log = task.loggingOutput(startedAt: startedAt, request: request, data: bytes, response: response)
			
			if usingCache {
				self.record(completedAt: Date(), cachedResponse: bytes, for: task)
			} else {
				self.record(completedAt: Date(), response: bytes, for: task)
				if self.storeResults, response.didDownloadSuccessfully, let index {
					self.types.value[index].store(results: log, from: startedAt, for: self) }
			}
			
			await self.dumpRecording(for: task)
		}
	}
	
	func updateSort(by: ConveyTaskReporter.Sort? = nil) {
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

extension ConveyTaskReporter {
	enum Sort: String, Sendable { case alpha, count, size, recent, enabled }
}

extension Array where Element == ConveyTaskReporter.LoggedTaskInfo {
	mutating func resetTaskTypes(for manager: ConveyTaskReporter) {
		for i in indices {
			self[i].dates = []
			self[i].thisRunBytes = 0
			self[i].clearStoredFiles(for: manager)
		}
	}
}
