//
//  RecordedTasksButton.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/29/25.
//

import SwiftUI

@available(iOS 17, watchOS 10, macOS 15, *)
public struct RecordedTasksButton: View {
	let showTaskCount: Bool
	var counter = TaskRecorderCount.instance
	@State private var showRecordedTasks = false
	public init(showTaskCount: Bool = true) {
		self.showTaskCount = showTaskCount
	}
	
	var title: String {
		guard showTaskCount else { return "Tasks" }
		let count = counter.count
		if count == 0 { return "Tasks" }
		return "Tasks (\(count))"
	}
	
	public var body: some View {
		Button(action: { showRecordedTasks.toggle() }) {
			HStack {
				Text("Tasks")
				if showTaskCount, counter.count > 0 {
					Text("\(counter.count)")
						.bold()
				}
			}
		}
			.buttonStyle(.bordered)
			.sheet(isPresented: $showRecordedTasks) {
				RecordedTasksScreen()
			}
			.task {
				if await TaskRecorder.instance.limit == TaskRecorder.Limit.none {
					print("⛔️ Tasks are not currently saved. Use TaskRecorder.instance.setSaveTaskLimit() to enable.")
				}
			}
	}
}
