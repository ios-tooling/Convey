//
//  RecordedTasksButton.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/29/25.
//

import SwiftUI

@available(iOS 17, watchOS 10, macOS 15, *)
public struct RecordedTasksButton: View {
	@State private var showRecordedTasks = false
	public init() { }
	
	public var body: some View {
		Button("Tasks") { showRecordedTasks.toggle() }
			.buttonStyle(.bordered)
			.sheet(isPresented: $showRecordedTasks) {
				RecordedTasksScreen()
			}
			.task {
				if await !TaskRecorder.instance.saveTasks {
					print("⛔️ Tasks are not currently saved. Use TaskRecorder.instance.setSaveTasks() to enable.")
				}
			}
	}
}
