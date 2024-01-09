//
//  ConveyConsoleView.swift
//
//
//  Created by Ben Gottlieb on 1/6/24.
//

import SwiftUI

class TaskResponseManager: ObservableObject {
	static let instance = TaskResponseManager()
	
	var results: [String: Data] = [:]
	var configurations: [String: [String: String]] = [:]
	
	func configurationBinding<TaskKind: ConfigurableConsoleDisplayableTask>(for task: TaskKind) -> Binding<[String: String]> {
		let key = String(describing: type(of: task))
		
		return Binding(
			get: { self.configurations[key] ?? [:] },
			set: { newValue in self.configurations[key] = newValue }
		)
	}
}

@available(iOS 16, macOS 13.0, *)
public struct ConveyConsoleView: View {
	var availableTasks: [any ConsoleDisplayableTask] = []
	@State var currentTaskIndex = 0
	@State private var isShowingConfigurationSheet = false
	@ObservedObject var responses = TaskResponseManager()
	
	public init(tasks: [any ConsoleDisplayableTask]) {
		self.availableTasks = tasks
	}
	
	public var body: some View {
		VStack {
			HStack {
				Picker("Task", selection: $currentTaskIndex) {
					ForEach(0..<availableTasks.count, id: \.self) { index in
						Text(availableTasks[index].displayString).tag(index)
					}
					
				}
				
				Button("Configure") {
					isShowingConfigurationSheet.toggle()
				}
				.disabled(!(availableTasks[currentTaskIndex] is ConfigurableConsoleDisplayableTask))
			}
			let task = availableTasks[currentTaskIndex]
			DisplayedTaskResultView(task: task, result: nil)
				.id(task.taskTag)
			Spacer()
			
		}
		.sheet(isPresented: $isShowingConfigurationSheet) {
			let task = availableTasks[currentTaskIndex] as! ConfigurableConsoleDisplayableTask
			ConsoleTaskConfigurationSheet(taskType: type(of: task), fields: responses.configurationBinding(for: task))
		}
		.padding()
	}
}
