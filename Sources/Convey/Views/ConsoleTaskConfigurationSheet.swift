//
//  ConsoleTaskConfigurationSheet.swift
//
//
//  Created by Ben Gottlieb on 1/8/24.
//

import SwiftUI

@available(iOS 16, macOS 13.0, *)
struct ConsoleTaskConfigurationSheet: View {
	let taskType: any ConfigurableConsoleDisplayableTask.Type
	@Binding var fields: [String: String]
	@Environment(\.dismiss) private var dismiss
	@Binding var newTask: (any ConfigurableConsoleDisplayableTask)?
	
	func binding(forField named: String) -> Binding<String> {
		Binding<String>(
			get: { fields[named] ?? "" },
			set: { newValue in
				fields[named] = newValue}
		)
	}
	
	var body: some View {
		VStack {
			ForEach(taskType.configurationFields) { field in
				LabeledContent {
					TextField(field.label, text: binding(forField: field.label))
				} label: {
					Text(field.label)
				}
				.onSubmit {
					save()
				}
			}
			
			Spacer()
			HStack {
				Button("Cancel", role: .cancel) {
					dismiss()
				}
				.buttonStyle(.bordered)
				Button("Run") {
					save()
				}
				.buttonStyle(.borderedProminent)
			}
		}
		.frame(minWidth: 400, minHeight: 200)
		.padding()
	}
	
	func save() {
		if let task = taskType.init(configuration: fields) {
			newTask = task
			dismiss()
		}
	}
}
