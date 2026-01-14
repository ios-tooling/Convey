//
//  File.swift
//  Convey
//
//  Created by Ben Gottlieb on 1/13/26.
//

import SwiftUI
import SwiftData

@available(iOS 18, macOS 14, watchOS 10, *)
extension RecordedTasksScreen {
	struct TaskList: View {
		let tasks: [RecordedTask]
		let predicate: Predicate<RecordedTask>
		@Environment(\.modelContext) var modelContext
		
		var body: some View {
			VStack {
				List {
					ForEach(tasks) { task in
						NavigationLink(destination: { RecordedTaskDetailScreen(task: task) }) {
							TaskRow(task: task)
							//							.opacity(currentSessionStartDate != task.sessionStartedAtDate ? 0.3 : 1)
						}
					}
					.onDelete { indices in
						for index in indices.reversed() {
							let task = tasks[index]
							modelContext.delete(task)
						}
						
						do {
							try modelContext.save()
						} catch {
							print("Failed to save recorded tasks context: \(error)")
						}
					}
				}
				.listStyle(.plain)
				.navigationTitle("Recorded Tasks (\(tasks.count))")
				.navigationBarTitleDisplayMode(.inline)
				.toolbar {
					ToolbarItem(id: "clear", placement: .destructiveAction) {
						Button("Delete", systemImage: "trash") {
							Task { await TaskRecorder.instance.clear(predicate: predicate) }
						}
					}
				}
			}
		}
	}
	
	struct RecentTasksTab: View {
		@Query(sort: \RecordedTask.startedAt, order: .reverse) var tasks: [RecordedTask]
		let sessionStartedAt: TimeInterval
		
		init(date: Date) {
			sessionStartedAt = date.timeIntervalSinceReferenceDate
			let sec = date.timeIntervalSinceReferenceDate
			let pred = #Predicate<RecordedTask> { task in sec == task.sessionStartedAt }
			_tasks = Query(filter: pred, sort: \RecordedTask.startedAt, order: .reverse)
		}
		
		var body: some View {
			TaskList(tasks: tasks, predicate:  #Predicate { task in
				task.appLaunchedAt == sessionStartedAt
		 })
		}
	}
	
	struct SearchTasksTab: View {
		@Query(sort: \RecordedTask.startedAt, order: .reverse) var tasks: [RecordedTask]
		let search: String
		
		init(text: String) {
			search = text
			if !text.isEmpty {
				let pred = #Predicate<RecordedTask> { task in task.name.localizedStandardContains(text) }
				_tasks = Query(filter: pred, sort: \RecordedTask.startedAt, order: .reverse)
			}
		}
		
		var body: some View {
			TaskList(tasks: tasks, predicate: #Predicate<RecordedTask> { task in task.name.localizedStandardContains(search) })
		}
	}
	
	struct AllTasksTab: View {
		@Query( sort: \RecordedTask.startedAt, order: .reverse) var tasks: [RecordedTask]
		
		var body: some View {
			TaskList(tasks: tasks, predicate: #Predicate<RecordedTask> { _ in true })
		}
	}

}
