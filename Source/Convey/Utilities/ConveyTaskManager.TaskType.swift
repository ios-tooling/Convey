//
//  File.swift
//  
//
//  Created by Ben Gottlieb on 6/19/22.
//

import Foundation
#if canImport(UIKit)
extension ConveyTaskManager {
	struct TaskType: Codable, Identifiable {
		enum CodingKeys: String, CodingKey { case taskName, totalCount, dates, totalBytes, thisRunBytes, manuallyEcho, compiledEcho }
		
		var id: String { taskName }
		let taskName: String
		var totalCount = 1
		var dates: [Date] = [Date()]
		var thisRunCount: Int { dates.count }
		var totalBytes: Int64 = 0
		var thisRunBytes: Int64 = 0
		var manuallyEcho: Bool?
		var thisRunOnlyEcho = false
		var compiledEcho = false
		var mostRecent: Date? { dates.last }
		var viewID: String { taskName + "\(String(describing: manuallyEcho))" }
		
		var hasStoredResults: Bool {
			!storedURLs.isEmpty
		}
		
		var shouldEcho: Bool {
			get { thisRunOnlyEcho || (manuallyEcho ?? compiledEcho) }
			set {
				if newValue == compiledEcho {
					manuallyEcho = nil
				} else {
					manuallyEcho = newValue
				}
			}
		}
		
		func store(results: Data, from date: Date) {
			if shouldEcho {
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
			for suffix in ["Task", "Request"] {
				if taskName.hasSuffix(suffix) {
					return String(taskName.dropLast(suffix.count))
				}
			}
			return taskName
		}
	}
}


fileprivate extension Date {
	var filename: String {
		var text = description.replacingOccurrences(of: ":", with: "˸")
		text = text.replacingOccurrences(of: "+0000", with: "")
		text.append(".\(Int(self.timeIntervalSinceReferenceDate * 100000) % 100000).txt")
		return text
	}
}
#endif
