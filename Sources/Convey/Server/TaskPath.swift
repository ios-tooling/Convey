//
//  TaskPath.swift
//
//
//  Created by Ben Gottlieb on 6/7/24.
//

import Foundation
import Combine

public actor TaskPath: ObservableObject, CustomStringConvertible {
	nonisolated let url: URL
	var count = 0
	public nonisolated var displayedCount: Int { recordedURLs.value.count }
	
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
			try? FileManager.default.removeItem(at: url.fileURL)
		}
		publish()
	}

	func load(_ url: URL) {
		try? FileManager.default.createDirectory(at: self.url, withIntermediateDirectories: true)
		print("Recording tasks to \(self.url.path)")
		
		do {
			recordedURLs.value = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil).map { url in
				
				TaskRecording(fileURL: url, date: url.creationDate ?? Date(), fromDisk: true, duration: nil)
			}.sorted()
		} catch {
			print("Failed to load task path URLs from \(error)")
		}
		count = recordedURLs.value.count
	}
	
	
	nonisolated func stop() {
		
	}
	
	public nonisolated var description: String {
		"Tasks stored at \(url.path)"
	}
	
	public nonisolated var logCount: Int {
		(try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]))?.count ?? 0
	}
	
	func publish() {
		Task { @MainActor in self.objectWillChange.send() }
	}
	
	func save(task: RecordedTask) async {
		guard let taskName = await task.task?.filename else { return }
		let filename = String(format: "%02d", count) + ". " + taskName
		let url = url.appendingPathComponent(filename)
		try? await task.output.write(to: url, atomically: true, encoding: .utf8)
		count += 1
		var urls = recordedURLs.value
		let duration = task.completedAt?.timeIntervalSince(task.startedAt ?? Date())
		urls.insert(TaskRecording(fileURL: url, date: Date(), duration: duration), at: 0)
		recordedURLs.value = urls
		publish()
	}
}
