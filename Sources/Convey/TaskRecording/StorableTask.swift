//
//  StorableTask.swift
//  Convey
//
//  Created by Ben Gottlieb on 3/11/26.
//

import Foundation

public protocol StorableTask: DownloadingTask, Codable { }

@available(iOS 17, macOS 14, watchOS 10, *)
extension TaskRecorder {
	public func register(_ task: any StorableTask.Type) {
		storableTaskTypes[String(describing: task)] = task
	}
	
	public func rebuildTask(data: Data?, name: String?) -> (any StorableTask)? {
		guard let data, let name, let type = storableTaskTypes[name] else { return nil }
		
		return try? JSONDecoder().decode(type, from: data)
	}
}
