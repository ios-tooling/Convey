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
		var url: URL?
		
		public static func <(lhs: Self, rhs: Self) -> Bool {
			lhs.date > rhs.date
		}
		
		init(fileURL: URL, date: Date) {
			self.fileURL = fileURL
			self.date = date
			
			if let raw = try? String(contentsOf: fileURL) {
				let pieces = raw.components(separatedBy: RecordedTask.separator)
				url = URL(string: pieces.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
			}
		}
	}
}
