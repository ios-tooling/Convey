//
//  TaskPath.swift
//
//
//  Created by Ben Gottlieb on 6/7/24.
//

import Foundation
import Combine

public actor TaskPath: ObservableObject {
	let url: URL
	var count = 0
	
	public struct TaskRecording: Identifiable, Comparable, Hashable {
		public var id: URL { url }
		public let url: URL
		public let date: Date
		
		public static func <(lhs: Self, rhs: Self) -> Bool {
			lhs.date > rhs.date
		}
	}
	
	let recordedURLs: CurrentValueSubject<[TaskRecording], Never> = .init([])
	nonisolated var urls: [TaskRecording] { recordedURLs.value }
	
	@available(iOS 16.0, macOS 13, watchOS 9, *)
	init(onDate: Date) {
		self.url = URL.documentsDirectory.appendingPathComponent("Task Recordings").appendingPathComponent(onDate.filename)

		Task { await load(self.url) }
	}

	@available(iOS 16.0, macOS 13, watchOS 9, *)
	init() {
		self.url = URL.documentsDirectory.appendingPathComponent("Task Recordings").appendingPathComponent("Recorded")

		Task { await load(self.url) }
	}

	init(url: URL) {
		self.url = url
		Task { await load(self.url) }
	}
	
	func clear() {
		let urls = recordedURLs.value
		recordedURLs.value = []
		count = 0
		
		for url in urls {
			try? FileManager.default.removeItem(at: url.url)
		}
		publish()
	}

	func load(_ url: URL) {
		try? FileManager.default.createDirectory(at: self.url, withIntermediateDirectories: true)
		print("Recording tasks to \(self.url.path)")
		
		do {
			recordedURLs.value = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil).map { url in
				
				TaskRecording(url: url, date: url.creationDate ?? Date())
			}.sorted()
		} catch {
			print("Failed to load task path URLs from \(error)")
		}
		count = recordedURLs.value.count
	}
	
	
	nonisolated func stop() {
		
	}
	
	func publish() {
		Task { @MainActor in self.objectWillChange.send() }
	}
	
	func save(task: RecordedTask) {
		guard let taskName = task.task?.filename else { return }
		let filename = String(format: "%02d", count) + ". " + taskName
		let url = url.appendingPathComponent(filename)
		try? task.output.write(to: url, atomically: true, encoding: .utf8)
		count += 1
		var urls = recordedURLs.value
		urls.insert(TaskRecording(url: url, date: Date()), at: 0)
		recordedURLs.value = urls
		publish()
	}
}
