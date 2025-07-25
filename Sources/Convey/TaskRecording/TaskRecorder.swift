//
//  File.swift
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
public actor TaskRecorder {
	public static let instance = TaskRecorder()
	
	public var saveTasks = false
	
	var appLaunchedAt = Date()
	var sessionStartedAt: Date?
	
	public func setup() {
		#if os(iOS) || os(visionOS)
			notificationTokens.append(NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main, using: { _ in
				Task { await self.startNewSession() }
			}))
		#endif
	}
	
	public func setSaveTasks(_ saveTasks: Bool) {
		self.saveTasks = saveTasks
	}
	
	nonisolated let _container: ModelContainer?
	var notificationTokens: [Any] = []
	
	nonisolated var container: ModelContainer? { _container }
	
	init() {
		let storeURL = URL.libraryDirectory.appending(path: "convey_tasks.db")
		let configuration = ModelConfiguration(url: storeURL)
		_container = try? ModelContainer(for: RecordedTask.self, configurations: configuration)
		Task { await self.setup() }
	}
	
	func startNewSession() {
		sessionStartedAt = Date()
	}
	
	func clearAll() {
		guard let container else { return }
		let ctx = ModelContext(container)
		
		try? ctx.delete(model: RecordedTask.self, where: #Predicate { task in true })
		
		try? ctx.save()
	}
	
	func clearOld() {
		guard let container else { return }
		let ctx = ModelContext(container)
		
		let launchTime = appLaunchedAt.timeIntervalSinceReferenceDate
		try? ctx.delete(model: RecordedTask.self, where: #Predicate { task in
			task.appLaunchedAt < launchTime
		})
		
		try? ctx.save()
	}
	
	func record(info: RequestTrackingInfo) async {
		if !saveTasks { return }
		guard let container = _container else {
			print("No Convey model container available.")
			return
		}
		let context = ModelContext(container)
		let record = RecordedTask(info: info, launchedAt: appLaunchedAt)
		record.appLaunchedAt = appLaunchedAt.timeIntervalSinceReferenceDate
		record.sessionStartedAt = (sessionStartedAt ?? appLaunchedAt).timeIntervalSinceReferenceDate
		context.insert(record)
		do {
			try context.save()
		} catch {
			print("Failed to save Convey recording context: \(error)")
		}
	}
}
