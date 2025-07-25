//
//  TaskRow.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/25/25.
//

import SwiftUI

@available(iOS 17, macOS 14, watchOS 10, *)
extension RecordedTasksScreen.TaskList {
	struct TaskRow: View {
		let task: RecordedTask
		static let formatter = ByteCountFormatter()

		var body: some View {
			VStack(alignment: .leading) {
				HStack {
					Text(task.name).bold()
						.font(.system(size: 13))
					Spacer()
					if let size = task.data?.count {
						Text(Self.formatter.string(fromByteCount: Int64(size)))
							.font(.system(size: 12))
					}
				}
				
				if let url = task.url {
					let prefix = (url.scheme ?? "") + "://" + (url.host() ?? "")
					
					Text(url.absoluteString.dropFirst(prefix.count))
						.font(.system(size: 11))
				}
				
				HStack {
					Text(task.startedAt.formatted(date: .abbreviated, time: .complete))
					Spacer()
					if let duration = task.duration {
						Text("\(duration.formatted())s")
					}
				}
				.font(.system(size: 10))
				.opacity(0.6)
			}
		}
	}
}
