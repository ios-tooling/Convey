//
//  ConveyConsoleView.swift
//
//
//  Created by Ben Gottlieb on 1/6/24.
//

import SwiftUI

#if os(macOS)
import Cocoa
#endif

@available(iOS 16, macOS 13.0, *)
@MainActor public struct ConveyConsoleView: View {
	@State var availableTasks: [any ConsoleDisplayableTask] = []
	@State var currentTaskIndex = 0
	@State private var isShowingConfigurationSheet = false
	@State private var isFetching = false
	@ObservedObject var responses = ConsoleTaskResponseCache()
	
	public init(tasks: [any ConsoleDisplayableTask]) {
		_availableTasks = State(initialValue: tasks)
	}
	
	public var body: some View {
		let task = responses.task(matching: availableTasks[currentTaskIndex])

		VStack {
			HStack {
				Picker("Task", selection: $currentTaskIndex) {
					ForEach(0..<availableTasks.count, id: \.self) { index in
						Text(availableTasks[index].displayString).tag(index)
					}
					
				}

				viewOnMacButton

				Button("Configure") {
					isShowingConfigurationSheet.toggle()
				}
				.disabled(isFetching || !(availableTasks[currentTaskIndex] is ConfigurableConsoleDisplayableTask))
				
				Button(action: {
					responses.clearResults(for: task)
				}) {
					Image(systemName: "arrow.counterclockwise")
				}
				.disabled(isFetching)
			}
			
			DisplayedTaskResultView(task: task, isFetching: $isFetching)
				.id(task.taskTag)
			Spacer()
			
		}
		.sheet(isPresented: $isShowingConfigurationSheet) {
			let task = availableTasks[currentTaskIndex] as! ConfigurableConsoleDisplayableTask
			ConsoleTaskConfigurationSheet(taskType: type(of: task), fields: responses.configurationBinding(for: task), newTask: newTaskBinding)
		}
		.padding()
		.environmentObject(responses)
	}
	
	@ViewBuilder var viewOnMacButton: some View {
		#if os(macOS)
		let task = availableTasks[currentTaskIndex]
		if let response = responses[task] {
			Button(action: {
				let url = URL.temporaryDirectory.appendingPathComponent(responses.filename(for: task, ext: "txt"))
				try! response.data.write(to: url)
				NSWorkspace.shared.open(url)
			}) {
				Image(systemName: "eye")
			}
		}
		#else
			EmptyView()
		#endif
	}
	
	var newTaskBinding: Binding<(any ConfigurableConsoleDisplayableTask)?> {
		Binding(
			get: { nil },
			set: { newValue in
				if let newValue {
					availableTasks[currentTaskIndex] = newValue
					responses.clearResults(for: newValue)
				}
			}
		)
	}
}
