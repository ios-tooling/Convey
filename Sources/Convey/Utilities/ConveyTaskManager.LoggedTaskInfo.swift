//
//  ConveyTaskManager.swift
//  
//
//  Created by Ben Gottlieb on 6/19/22.
//

import Foundation
import SwiftUI

extension ConveyTaskManager {
	struct LoggedTaskInfo: Codable, Identifiable {
		enum CodingKeys: String, CodingKey { case taskName, totalCount, dates, totalBytes, thisRunBytes, manuallyEcho, suppressCompiledEcho }
		
		var id: String { taskName }
		let taskName: String
		var totalCount = 1
		var dates: [Date] = [Date()]
		var thisRunCount: Int { dates.count }
		var totalBytes: Int64 = 0
		var thisRunBytes: Int64 = 0
		var manuallyEcho: Bool?
		var thisRunOnlyEcho = false
		var suppressCompiledEcho = false
		var compiledEcho = false
		var mostRecent: Date? { dates.last }
		var viewID: String { taskName + String(describing: manuallyEcho) }
		
		var hasStoredResults: Bool {
			!storedURLs.isEmpty
		}
		
		func shouldEcho(_ task: ServerTask.Type? = nil) -> Bool {
			if let task, task is EchoingTask.Type, !suppressCompiledEcho { return true }
			if ConveyTaskManager.instance.oneOffTypes.contains(taskName) { return true }
			if let manual = manuallyEcho { return manual }
			if !suppressCompiledEcho, compiledEcho { return true }
			return thisRunOnlyEcho
		}

		mutating func setShouldEcho(_ newValue: Bool) {
			withAnimation {
				if thisRunOnlyEcho {
					manuallyEcho = newValue ? nil : false
				} else if newValue == manuallyEcho {
					manuallyEcho = nil
					if !newValue { suppressCompiledEcho = true }
				} else {
					manuallyEcho = newValue
				}
			}
		}
		
		
		func store(results: Data, from date: Date) {
			if shouldEcho(nil) {
				print("Storing data for \(name) at \(date.filename)")
				let typeURL = directory
				try? FileManager.default.createDirectory(at: typeURL, withIntermediateDirectories: true)
				let fileURL = typeURL.appendingPathComponent(date.filename)
				try? results.write(to: fileURL)
			}
		}
		
		func clearStoredFiles() {
			try? FileManager.default.removeItem(at: directory)
		}
		
		var storedURLs: [URL] { (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? [] }
		
		var directory: URL {
			ConveyTaskManager.instance.directory.appendingPathComponent(taskName)
		}
		
		var thisRunBytesString: String {
			ByteCountFormatter().string(fromByteCount: thisRunBytes)
		}
		
		var totalBytesString: String {
			ByteCountFormatter().string(fromByteCount: totalBytes)
		}
		
		var name: String {
			taskName.prettyConveyTaskName
		}
	}
}

extension String {
	var prettyConveyTaskName: String {
		for suffix in ["Task", "Request"] {
			if hasSuffix(suffix) {
				return String(dropLast(suffix.count))
			}
		}
		return self
	}
}

extension Date {
	var filename: String {
		var text = description.filename
		text = text.replacingOccurrences(of: "+0000", with: "").trimmingCharacters(in: .whitespaces)
		text.append(".\(Int(self.timeIntervalSinceReferenceDate * 100000) % 100000).txt")
		return text
	}
}
