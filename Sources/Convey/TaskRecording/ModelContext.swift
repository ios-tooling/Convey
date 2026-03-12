//
//  ModelContext.swift
//  Convey
//
//  Created by Ben Gottlieb on 3/11/26.
//

import Foundation
import SwiftData

@available(iOS 17, macOS 14, watchOS 10, *)
extension ModelContext {
	func fetch(taskID id: String) -> RecordedTask? {
		let predicate = #Predicate<RecordedTask> { $0.uniqueID == id }
		var request = FetchDescriptor(predicate: predicate)
		request.fetchLimit = 1
		return (try? fetch(request))?.first
	}
	
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
