//
//  TaskResponseManager.swift
//
//
//  Created by Ben Gottlieb on 1/9/24.
//

import SwiftUI

@MainActor class ConsoleTaskResponseCache: ObservableObject {
	static let instance = ConsoleTaskResponseCache()
	
	var results: [String: ServerResponse] = [:]
	var configurations: [String: [String: String]] {
		get { (UserDefaults.standard.dictionary(forKey: Self.savedConfigurationsKey) as? [String: [String: String]]) ?? [:] }
		set {
			UserDefaults.standard.setValue(newValue, forKey: Self.savedConfigurationsKey)
		}
	}
	
	func filename(for task: any ConsoleDisplayableTask, ext: String = "json") -> String {
		task.resultsKey + "." + ext
	}
	
	static var savedConfigurationsKey = String(describing: ConsoleTaskResponseCache.self)
	
	func save(_ response: ServerResponse, for task: any ConsoleDisplayableTask) {
		self[task] = response
	}

	subscript(task: any ConsoleDisplayableTask) -> ServerResponse? {
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
	
	func task(matching: any ConsoleDisplayableTask) -> any ConsoleDisplayableTask {
		if let configurable = matching as? (any ConfigurableConsoleDisplayableTask), let opts = configurations[configurable.resultsKey] {
			return type(of: configurable).init(configuration: opts) ?? matching
		}
		
		return matching
	}
}

fileprivate extension ServerTask {
	nonisolated var resultsKey: String { String(describing: type(of: self)) }
}
