//
//  RecordedTasksButton.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/29/25.
//

import SwiftUI

@available(iOS 17, macOS 15, *)
public struct RecordedTasksButton: View {
	@State private var showRecordedTasks = false
	public init() { }
	
	public var body: some View {
		Button("Tasks") { showRecordedTasks.toggle() }
			.buttonStyle(.bordered)
			.sheet(isPresented: $showRecordedTasks) {
				RecordedTasksScreen()
			}
		
	}
}
