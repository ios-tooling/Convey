//
//  RecordedTasksScreen.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/25/25.
//

import SwiftUI
import SwiftData

@available(iOS 18, macOS 15, watchOS 10, *)
public struct RecordedTasksScreen: View {
	public init() { }
	@State var context: ModelContext?
	@State var currentAppLaunchDate: Date?
	@State var currentSessionStartDate: Date?
	
	
	public var body: some View {
		VStack {
			if let context {
				TaskTabs(currentAppLaunchDate: currentAppLaunchDate, currentSessionStartDate: currentSessionStartDate)
					.modelContext(context)
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

@available(iOS 18, macOS 15, watchOS 10, *)
extension RecordedTasksScreen {
	struct TaskTabs: View {
		var currentAppLaunchDate: Date?
		var currentSessionStartDate: Date?
		var counter = TaskRecorderCount.instance
		@State private var searchText = ""

		@Environment(\.modelContext) var modelContext
		@Query(sort: \RecordedTask.startedAt, order: .reverse) var tasks: [RecordedTask]
		
		var body: some View {
			TabView {
				Tab("Recent", systemImage: "clock") {
					NavigationStack {
						RecentTasksTab(date: currentSessionStartDate ?? .now)
					}
				}

				Tab("All", systemImage: "list.triangle") {
					NavigationStack {
						AllTasksTab()
					}
				}
				
				Tab("Search", systemImage: "magnifyingglass", role: .search) {
					NavigationStack {
						SearchTasksTab(text: searchText)
							.searchable(text: $searchText)
							.font(.body)
					}
				}
			}

			
//			.toolbar {
//				ToolbarItem(placement: toolbarPlacement) {
//					Button("Clear Old") {
//						Task { await TaskRecorder.instance.clearOld() }
//					}
//					.fixedSize()
//				}
//
//				ToolbarItem(placement: toolbarPlacement) {
//					Button("Clear All") {
//						Task { await TaskRecorder.instance.clearAll() }
//					}
//					.fixedSize()
//				}
//			}
//			.buttonStyle(.bordered)
		}

		var toolbarPlacement: ToolbarItemPlacement {
			#if os(macOS)
				.automatic
			#else
				.bottomBar
			#endif
		}
	}
}

