//
//  RecordedTask+Retry.swift
//  Convey
//
//  Created by Ben Gottlieb on 3/12/26.
//

import Foundation
import SwiftData

@available(iOS 17, macOS 14, watchOS 10, *)
extension TaskRecorder {
	public func pendingTaskCount<TaskType: StorableTask>(ofType: TaskType.Type) -> Int {
		guard let container else { return 0 }
		let ctx = ModelContext(container)
		let name = String(describing: TaskType.self)
		let predicate = #Predicate<RecordedTask> { $0.isComplete == false && $0.name == name }
		return (try? ctx.fetchCount(FetchDescriptor(predicate: predicate))) ?? 0
	}

	public func printPendingTaskSummary() {
		guard let container else { return }
		let ctx = ModelContext(container)

		for (name, _) in storableTaskTypes {
			let predicate = #Predicate<RecordedTask> { $0.isComplete == false && $0.name == name }
			let count = (try? ctx.fetchCount(FetchDescriptor(predicate: predicate))) ?? 0
			if count > 0 {
				print("\(name): \(count) pending")
			}
		}
	}

	public func retryAllTasks<TaskType: StorableTask>(ofType: TaskType.Type) async {
		guard let container else { return }
		let ctx = ModelContext(container)
		let name = String(describing: TaskType.self)
		let predicate = #Predicate<RecordedTask> { $0.isComplete == false && $0.name == name }
		let recorded = (try? ctx.fetch(FetchDescriptor(predicate: predicate))) ?? []

		for record in recorded {
			guard let task = record.storableTask(TaskType.self) else { continue }

			do {
				let _ = try await task.download(usingRecordedTaskID: record.uniqueID)
			} catch {
				record.retryCount += 1
				try? ctx.save()
			}
		}

	}
}
