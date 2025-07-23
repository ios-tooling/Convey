//
//  File.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/22/25.
//

import Foundation

import SwiftData

@available(iOS 17, macOS 14, watchOS 10, *)
public actor TaskRecorder {
	static let instance = TaskRecorder()
	
	public var saveTasks = false
	
	public func setSaveTasks(_ saveTasks: Bool) {
		self.saveTasks = saveTasks
	}
	
	let container: ModelContainer?
	
	init() {
		let storeURL = URL.libraryDirectory.appending(path: "convey_tasks.db")
		let configuration = ModelConfiguration(url: storeURL)
		container = try? ModelContainer(for: RecordedTask.self, configurations: configuration)
	}
	func record(info: RequestTrackingInfo) async {
		if !saveTasks { return }
		guard let container else {
			print("No Convey model container available.")
			return
		}
		let context = ModelContext(container)
		let record = RecordedTask(info: info)
		context.insert(record)
		do {
			try context.save()
		} catch {
			print("Failed to save Convey recording context: \(error)")
		}
	}
}

@available(iOS 17, macOS 14, watchOS 10, *)
@Model class RecordedTask {
	var url: URL?
	var name: String
	var blurb: String
	var requestData: Data?
	var responseData: Data?
	var data: Data?
	var startedAt: Date
	var duration: TimeInterval?
	var error: String?
	var downloadSize: Int?
	
	init(info: RequestTrackingInfo) {
		url = info.url
		name = info.taskName
		blurb = info.taskDescription
		duration = info.duration
		startedAt = info.startedAt
		error = info.error
		downloadSize = info.data?.count
		data = info.data
		
		if let request = info.request {
			requestData = try? JSONEncoder().encode(request)
		}

		if let response = info.response {
			responseData = try? JSONEncoder().encode(response)
		}
	}
}
