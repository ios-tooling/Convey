//
//  TaskReporterView.swift
//
//
//  Created by Ben Gottlieb on 6/18/22.
//

import SwiftUI

#if canImport(UIKit)
@available(watchOS, unavailable)
@MainActor public struct TaskReporterView: View {
	@ObservedObject private var observer = TaskReporterObserver()
	@State private var sort: ConveyTaskReporter.Sort = .alpha
	@State private var reporter: ConveyTaskReporter?
	
	public init() {
	}
	
	public var body: some View {
		VStack() {
			Picker("", selection: $sort.animation()) {
				Text("Alpha").tag(ConveyTaskReporter.Sort.alpha)
				Text("Count").tag(ConveyTaskReporter.Sort.count)
				Text("Size").tag(ConveyTaskReporter.Sort.size)
				Text("Date").tag(ConveyTaskReporter.Sort.recent)
				Text("On").tag(ConveyTaskReporter.Sort.enabled)
			}
			.pickerStyle(.segmented)
			.padding()
			
			if let reporter {
				let types = reporter.sortedTypes
				List(types.indices, id: \.self) { index in
					TaskTypeRow(taskType: types[index], manager: reporter)
				}
				.listStyle(.plain)
				
				HStack() {
					Button("All Off") { reporter.turnAllOff() }.padding()
						.disabled(reporter.areAllOff)
					Button("Reset All") { reporter.resetAll() }.padding()
						.disabled(!reporter.canResetAll)
					
					Button("Reset Current") {
						Task {
							var sortedTypes = reporter.sortedTypes
							sortedTypes.resetTaskTypes(for: reporter)
							reporter.sortedTypes = sortedTypes
						}
					}
					.padding()
				}
			}
		}
		 .navigationBarTitle("Network Tasks")
		 .onChange(of: sort) { newValue in
			 Task { @MainActor in
				 reporter = await ConveyTaskReporter.instance
				 await ConveyTaskReporter.instance.updateSort(by: newValue)
				 observer.objectWillChange.send()
			 }
		 }
		 .onAppear {
			 Task {
				 sort = await ConveyTaskReporter.instance.sort.value
			 }
		 }
    }
	
	@MainActor struct TaskTypeRow: View {
		@State var taskType: ConveyTaskReporter.LoggedTaskInfo
		let manager: ConveyTaskReporter
		
		var body: some View {
			Group {
				if taskType.hasStoredResults(for: manager) {
					ZStack() {
						NavigationLink(destination: TaskResultsListView(taskType: taskType, manager: manager)) { rowContent }.opacity(0.5)
						rowContent
					}
				} else {
					rowContent
				}
			}
			.id(taskType.taskName)
		}
		
		var rowContent: some View {
			HStack(spacing: 20) {
				VStack(spacing: 0) {
					Button(action: {
						taskType.setShouldEcho(!taskType.shouldEcho(nil, for: manager))
					}) {
						Text("Echo")
							.font(.system(size: 12, weight: .bold).smallCaps())
							.padding(.vertical, 5)
							.padding(.horizontal, 10)
							.foregroundColor(taskType.shouldEcho(nil, for: manager) ? .white : .blue)
							.background(Capsule().fill(taskType.shouldEcho(nil, for: manager) ? .blue : .white))
							.overlay(Capsule().stroke(.blue))
					}
					.buttonStyle(.plain)
				}
				.opacity((taskType.manuallyEcho != nil || taskType.thisRunOnlyEcho) ? 1 : 0.5)
				.id(taskType.viewID)

				VStack(alignment: .leading) {
					Text(taskType.name)
						.font(.body)
					Text("This run: \(taskType.thisRunBytesString) (\(taskType.thisRunCount))")
					Text("Total: \(taskType.totalBytesString) (\(taskType.totalCount))")
					if let recent = taskType.mostRecent {
						Text("Recent: \(recent.timeString)")
					}
				}
				.font(.caption)
				Spacer()
			}
		}
	}
}

@available(watchOS, unavailable)
struct TaskReporterView_Previews: PreviewProvider {
    static var previews: some View {
		 TaskReporterView()
    }
}

@available(watchOS, unavailable)
fileprivate extension Date {
	var timeString: String {
		if #available(iOS 15.0, watchOS 8.0, *) {
			return formatted(date: .omitted, time: .complete)
		} else {
			return description
		}
	}
}

#endif
