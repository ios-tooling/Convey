//
//  RecordedTask+Retry.swift
//  Convey
//
//  Created by Ben Gottlieb on 3/12/26.
//

import Foundation
import SwiftData

@available(iOS 17, macOS 14, watchOS 10, *)
extension RecordedTask {
	func retry<TaskType: StorableTask>(for type: TaskType.Type) async {
		guard let task = await storableTask as? TaskType, let modelContext else { return }
		
		do {
			print("Retrying \(TaskType.self), #\(retryCount + 1)")
			let _ = try await task.download(usingRecordedTaskID: uniqueID)
			retrySuccessfulAt = .now
			isComplete = true
		} catch {
			retryCount += 1
		}
		
		try? modelContext.save()
	}
}

@available(iOS 17, macOS 14, watchOS 10, *)
extension TaskRecorder {
	public func retryAllTasks<TaskType: StorableTask>(ofType: TaskType.Type) async {
		guard let container else { return }
		let ctx = ModelContext(container)
		let name = String(describing: TaskType.self)
		let predicate = #Predicate<RecordedTask> { $0.isComplete == false && $0.name == name }
		let recorded = (try? ctx.fetch(FetchDescriptor(predicate: predicate))) ?? []
		
		for record in recorded {
			await record.retry(for: TaskType.self)
		}
	}
}
