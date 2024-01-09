//
//  TaskResponseManager.swift
//
//
//  Created by Ben Gottlieb on 1/9/24.
//

import SwiftUI

class TaskResponseManager: ObservableObject {
	static let instance = TaskResponseManager()
	
	var results: [String: ServerReturned] = [:]
	var configurations: [String: [String: String]] = [:]
	
	subscript(task: any ConsoleDisplayableTask) -> ServerReturned? {
		get { results[task.resultsKey] }
		set {
			results[task.resultsKey] = newValue
			Task { @MainActor in self.objectWillChange.send() }
		}
	 }
	
	func clearResults(for task: any ConsoleDisplayableTask) {
		let key = task.resultsKey
		
		if results[key] != nil {
			results.removeValue(forKey: key)
			objectWillChange.send()
		}
	}
	
	func configurationBinding<TaskKind: ConfigurableConsoleDisplayableTask>(for task: TaskKind) -> Binding<[String: String]> {
		let key = task.resultsKey
		
		return Binding(
			get: { self.configurations[key] ?? [:] },
			set: {
				newValue in self.configurations[key] = newValue
				Task { @MainActor in self.objectWillChange.send() }
			}
		)
	}
}

fileprivate extension ServerTask {
	var resultsKey: String { String(describing: type(of: self)) }
}
