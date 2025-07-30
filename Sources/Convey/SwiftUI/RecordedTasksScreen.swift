//
//  RecordedTasksScreen.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/25/25.
//

import SwiftUI
import SwiftData

@available(iOS 17, macOS 14, watchOS 10, *)
public struct RecordedTasksScreen: View {
	public init() { }
	@State var context: ModelContext?
	@State var currentAppLaunchDate: Date?
	@State var currentSessionStartDate: Date?
	
	
	public var body: some View {
		NavigationStack {
			VStack {
				if let context {
					TaskList(currentAppLaunchDate: currentAppLaunchDate, currentSessionStartDate: currentSessionStartDate)
						.modelContext(context)
				}
			}
		}
		.task {
			currentAppLaunchDate = await TaskRecorder.instance.appLaunchedAt
			currentSessionStartDate = await TaskRecorder.instance.sessionStartedAt ?? currentAppLaunchDate
			if let container = TaskRecorder.instance.container {
				context = ModelContext(container)
			}
		}
	}
}

@available(iOS 17, macOS 14, watchOS 10, *)
extension RecordedTasksScreen {
	struct TaskList: View {
		var currentAppLaunchDate: Date?
		var currentSessionStartDate: Date?
		
		@Environment(\.modelContext) var modelContext
		@Query(sort: \RecordedTask.startedAt, order: .reverse) var tasks: [RecordedTask]
		
		
		var body: some View {
			VStack {
				Text("Recorded Tasks (\(tasks.count))")
					.font(.title)
				List {
					ForEach(tasks) { task in
						NavigationLink(destination: { RecordedTaskDetailScreen(task: task) }) {
							TaskRow(task: task)
								.opacity(currentSessionStartDate != task.sessionStartedAtDate ? 0.3 : 1)
						}
					}
					.onDelete { indices in
						for index in indices.reversed() {
							let task = tasks[index]
							modelContext.delete(task)
						}
						try? modelContext.save()
					}
				}
				.listStyle(.plain)
			}
			HStack {
				Button("Clear Old") {
					Task { await TaskRecorder.instance.clearOld() }
				}
				
				Button("Clear All") {
					Task { await TaskRecorder.instance.clearAll() }
				}
			}
			.buttonStyle(.bordered)
		}
	}
}

