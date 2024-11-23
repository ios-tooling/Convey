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

#if os(iOS) || os(macOS) || os(visionOS)
@available(iOS 16, macOS 13.0, *)
@MainActor public struct ConveyConsoleView: View {
	@State var availableTasks: [any ConsoleDisplayableTask] = []
	@State var currentTaskIndex = 0
	@State private var isShowingConfigurationSheet = false
	@State private var isFetching = false
	@ObservedObject var responses = ConsoleTaskResponseCache()
	@State private var isConsoleDisplayable = false
	@State private var taskTag = UUID().uuidString
	@State private var currentTask: (any ConsoleDisplayableTask)?
	
	public init(tasks: [any ConsoleDisplayableTask]) {
		_availableTasks = State(initialValue: tasks)
	}
	
	public var body: some View {
		VStack {
			if let currentTask {
				HStack {
					Picker("Task", selection: $currentTaskIndex) {
						ForEach(0..<availableTasks.count, id: \.self) { index in
							TaskRow(task: availableTasks[index]).tag(index)
						}
						
					}
					
					viewOnMacButton
					
					Button("Configure") {
						isShowingConfigurationSheet.toggle()
					}
					.disabled(isFetching || !isConsoleDisplayable)
					
					Button(action: {
						responses.clearResults(for: currentTask)
					}) {
						Image(systemName: "arrow.counterclockwise")
					}
					.disabled(isFetching)
				}
				
				DisplayedTaskResultView(task: currentTask, isFetching: $isFetching)
					.id(taskTag)
				
			}
			Spacer()
		}
		.onAppear {
			Task {
				currentTask = await responses.task(matching: availableTasks[currentTaskIndex])
				isConsoleDisplayable = await availableTasks[currentTaskIndex].wrappedTask is any ConfigurableConsoleDisplayableTask
				taskTag = await currentTask?.taskTag ?? ""
			}
		}
		.sheet(isPresented: $isShowingConfigurationSheet) {
			let task = availableTasks[currentTaskIndex] as! any ConfigurableConsoleDisplayableTask
			ConsoleTaskConfigurationSheet(taskType: type(of: task), fields: responses.configurationBinding(for: task), newTask: newTaskBinding)
		}
		.padding()
		.environmentObject(responses)
	}
	
	struct TaskRow: View {
		let task: any ConsoleDisplayableTask
		@State var text = ""
		
		var body: some View {
			Text(text)
				.task {
					text = await task.displayString
				}
		}
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
#endif
