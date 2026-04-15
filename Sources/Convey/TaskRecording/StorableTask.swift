//
//  StorableTask.swift
//  Convey
//
//  Created by Ben Gottlieb on 3/11/26.
//

import Foundation

public protocol StorableTask: DownloadingTask, Codable { }

@available(iOS 17, macOS 14, watchOS 10, *)
extension TaskRecovery {
	public func register(_ task: any StorableTask.Type, callback: (() async -> Void)? = nil) {
		storableTaskTypes[String(describing: task)] = task
		if let callback {
			addRetryCallback(for: task, callback)
		} else {
			addRetryCallback(for: task) {
				await self.retryAllTasks(ofType: task)
			}
		}
	}
	
	public func rebuildTask(data: Data?, name: String?) -> (any StorableTask)? {
		guard let data, let name, let type = storableTaskTypes[name] else { return nil }
		
		return try? JSONDecoder().decode(type, from: data)
	}
	
	
	public func addRetryCallback(for type: any StorableTask.Type, _ callback: @escaping () async -> Void) {
		let id = String(describing: type)
		if let index = retryCallbacks.firstIndex(where: { $0.id == id }) {
			retryCallbacks[index].retryCallback = callback
		} else {
			retryCallbacks.append(.init(retryCallback: callback, id: id))
		}

		Task {
			await self.retryAllFailedTasks()
		}
	}
	
}
