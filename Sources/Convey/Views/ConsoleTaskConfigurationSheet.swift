//
//  ConsoleTaskConfigurationSheet.swift
//
//
//  Created by Ben Gottlieb on 1/8/24.
//

import SwiftUI

#if os(iOS) || os(macOS) || os(visionOS)
@available(iOS 16, macOS 13.0, *)
@MainActor struct ConsoleTaskConfigurationSheet: View {
	let taskType: any ConfigurableConsoleDisplayableTask.Type
	@Binding var fields: [String: String]
	@Environment(\.dismiss) private var dismiss
	@Binding var newTask: (any ConfigurableConsoleDisplayableTask)?
	@State var configFields: [ConsoleConfigurationField] = []
	
	func binding(forField field: ConsoleConfigurationField) -> Binding<String> {
		Binding<String>(
			get: { fields[field.label] ?? field.defaultValue ?? "" },
			set: { newValue in
				fields[field.label] = newValue}
		)
	}
	
	var body: some View {
		VStack {
			ForEach(configFields) { field in
				LabeledContent {
					TextField(field.label, text: binding(forField: field))
				} label: {
					Text(field.label)
				}
				.onSubmit {
					save()
				}
			}
			.task {
				configFields = await taskType.configurationFields
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
		Task {
			if let task = await taskType.init(configuration: fields) {
				newTask = task
				dismiss()
			}
		}
	}
}
#endif
