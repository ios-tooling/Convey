//
//  TaskPath.TaskRecording.swift
//
//
//  Created by Ben Gottlieb on 6/10/24.
//

import Foundation

extension TaskPath {
	public struct TaskRecording: Identifiable, Comparable, Hashable {
		public var id: URL { fileURL }
		public let fileURL: URL
		public let date: Date
		public let payloadSize: Int64?
		public let duration: TimeInterval?
		var url: URL?
		public let fromDisk: Bool
		
		public static func <(lhs: Self, rhs: Self) -> Bool {
			lhs.date > rhs.date
		}
		
		init(fileURL: URL, date: Date, fromDisk: Bool = false, duration: TimeInterval?) {
			self.fileURL = fileURL
			self.date = date
			self.fromDisk = fromDisk
			self.duration = duration
			
			if let raw = try? String(contentsOf: fileURL) {
				let pieces = raw.components(separatedBy: RecordedTask.separator).filter { !$0.isEmpty }
				url = URL(string: pieces.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
				if pieces.count > 2 {
					payloadSize = Int64(pieces[pieces.count - 2].count)
				} else {
					payloadSize = nil
				}
			} else {
				payloadSize = nil
			}
		}
	}
}
