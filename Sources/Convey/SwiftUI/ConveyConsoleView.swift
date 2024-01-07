//
//  ConveyConsoleView.swift
//
//
//  Created by Ben Gottlieb on 1/6/24.
//

import SwiftUI

@available(iOS 15, macOS 13.0, *)
public struct ConveyConsoleView: View {
	var availableTasks: [any ConsoleDisplayableTask] = []
	@State var currentTaskIndex = 0
	
	public init(tasks: [any ConsoleDisplayableTask]) {
		self.availableTasks = tasks
	}
	
	public var body: some View {
		VStack {
			Picker("Task", selection: $currentTaskIndex) {
				ForEach(0..<availableTasks.count, id: \.self) { index in
					Text(availableTasks[index].displayString).tag(index)
				}
				
			}
			DisplayedTaskResultView(task: availableTasks[currentTaskIndex], result: nil)
			
			Spacer()
			
		}
		.padding()
	}
}
