//
//  TaskRecorder.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/22/25.
//

import Foundation
import SwiftData
import Combine

#if canImport(UIKit)
	import UIKit
#endif

@available(iOS 17, macOS 14, watchOS 10, *)
@MainActor @Observable class TaskRecorderCount {
	static let instance = TaskRecorderCount()
	var count = 0
}

@available(iOS 17, macOS 14, watchOS 10, *)
public actor TaskRecorder {
	public static let instance = TaskRecorder()
	
	public var limit = Limit.none
	
	var appLaunchedAt = Date()
	var sessionStartedAt: Date?
	
	public func setup() {
		#if os(iOS) || os(visionOS)
			notificationTokens.append(NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main, using: { _ in
				Task { await self.startNewSession() }
			}))
			updateTaskCount()
		#endif
	}
	
	nonisolated public func setSaveTaskLimit(_ limit: Limit = .days(7)) {
		Task { await self._setSaveTaskLimit(limit) }
	}

	func _setSaveTaskLimit(_ limit: Limit) {
		self.limit = limit
	}

	nonisolated let _container: ModelContainer?
	var notificationTokens: [Any] = []
	
	nonisolated var container: ModelContainer? { _container }
	
	init() {
		if CommandLine.failAllRequests {
			print("### ALL REQUEST WILL FAIL - COMMAND LINE OPTION SET ###")
		}
		let storeURL = URL.libraryDirectory.appending(path: "convey_tasks.db")
		let configuration = ModelConfiguration(url: storeURL)
		_container = try? ModelContainer(for: RecordedTask.self, configurations: configuration)
		Task { await self.setup() }
	}
	
	func updateTaskCount() {
		guard let container else { return }
		do {
			let count = try ModelContext(container).fetchCount(FetchDescriptor<RecordedTask>())
			Task { @MainActor in
				TaskRecorderCount.instance.count = count
			}
		} catch {
			print("Failed to fetch task count: \(error)")
		}
	}
	
	func startNewSession() {
		sessionStartedAt = Date()
	}
	
	func reportedSave(_ context: ModelContext) {
		do {
			try context.save()
			updateTaskCount()
		} catch {
			print("Failed to save context: \(error)")
		}
	}
	
	func clearAll() {
		guard let container else { return }
		let ctx = ModelContext(container)
		
		try? ctx.delete(model: RecordedTask.self, where: #Predicate { task in true })
		
		reportedSave(ctx)
		updateTaskCount()
	}
	
	func clear(predicate: Predicate<RecordedTask>) {
		guard let container else { return }
		let ctx = ModelContext(container)
		
		try? ctx.delete(model: RecordedTask.self, where: predicate)
		
		reportedSave(ctx)
		updateTaskCount()
	}
	
	func record(info: RequestTrackingInfo) async {
		guard let container = _container else {
			print("No Convey model container available.")
			return
		}
		let context = ModelContext(container)
		defer { updateTaskCount() }
		if !context.shouldSaveTask(limit: limit) { return }
		let record = RecordedTask(info: info, launchedAt: appLaunchedAt)
		record.appLaunchedAt = appLaunchedAt.timeIntervalSinceReferenceDate
		record.sessionStartedAt = (sessionStartedAt ?? appLaunchedAt).timeIntervalSinceReferenceDate
		context.insert(record)
		reportedSave(context)
	}
}

@available(iOS 17, macOS 14, watchOS 10, *)
public extension TaskRecorder {
	enum Limit: Sendable, Equatable { case none, after(Date), days(Int), count(Int), all }
}

@available(iOS 17, macOS 14, watchOS 10, *)
extension ModelContext {
	func shouldSaveTask(limit: TaskRecorder.Limit) -> Bool {
		switch limit {
		case .none: return false
		case .after(let date):
			if date > .now { return false }
			removeTasks(before: date)
			
		case .days(let days):
			let date = Date.now.addingTimeInterval(-1440 * 60 * Double(days))
			if date > .now { return false }
			removeTasks(before: date)

		case .count(let count):
			removeTasks(greaterThan: count)
		case .all: break
		}
		
		return true
	}
	
	func removeTasks(before date: Date) {
		let pred = #Predicate<RecordedTask> { $0.startedAt < date }
		do {
			try delete(model: RecordedTask.self, where: pred)
			try save()
		} catch {
			print("Failed to remove old tasks: \(error)")
		}
	}
	
	func removeTasks(greaterThan count: Int) {
		let request = FetchDescriptor<RecordedTask>(sortBy: [SortDescriptor(\.startedAt)])
		guard let all = try? fetch(request), all.count > count else { return }
		
		do {
			for i in 0...(all.count - count) {
				delete(all[i])
			}
			try save()
		} catch {
			print("Failed to remove old tasks: \(error)")
		}
	}
}
