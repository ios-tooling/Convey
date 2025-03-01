//
//  ConveyTaskReporter.swift
//  
//
//  Created by Ben Gottlieb on 6/19/22.
//

import Foundation
import SwiftUI

extension ConveyTaskReporter {
	struct LoggedTaskInfo: Codable, Identifiable, Sendable {
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
		
		func hasStoredResults(for manager: ConveyTaskReporter) -> Bool {
			!storedURLs(for: manager).isEmpty
		}
		
		func shouldEcho(_ task: (any ServerTask.Type)? = nil, for manager: ConveyTaskReporter) -> Bool {
			if let task, task is any EchoingTask.Type, !suppressCompiledEcho { return true }
			if manager.oneOffTypes.value.contains(taskName) { return true }
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
		
		
		func store(results: Data, from date: Date, for manager: ConveyTaskReporter) {
			if shouldEcho(nil, for: manager) {
				print("Storing data for \(name) at \(date.filename)")
				let typeURL = directory(for: manager)
				try? FileManager.default.createDirectory(at: typeURL, withIntermediateDirectories: true)
				let fileURL = typeURL.appendingPathComponent(date.filename)
				try? results.write(to: fileURL)
			}
		}
		
		func clearStoredFiles(for manager: ConveyTaskReporter) {
			try? FileManager.default.removeItemIfExists(at: directory(for: manager))
		}
		
		func storedURLs(for manager: ConveyTaskReporter) -> [URL] { (try? FileManager.default.contentsOfDirectory(at: directory(for: manager), includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? [] }
		
		func directory(for manager: ConveyTaskReporter) -> URL {
			manager.directory.appendingPathComponent(taskName)
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
