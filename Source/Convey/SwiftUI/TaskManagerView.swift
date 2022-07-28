//
//  TaskManagerView.swift
//  
//
//  Created by Ben Gottlieb on 6/18/22.
//

import SwiftUI

#if canImport(UIKit)
@available(watchOS, unavailable)
public struct TaskManagerView: View {
	@ObservedObject private var manager = ConveyTaskManager.instance
	
	public init() { }
	
	public var body: some View {
		 VStack() {
			 Picker("", selection: $manager.sort.animation()) {
				 Text("Alpha").tag(ConveyTaskManager.Sort.alpha)
				 Text("Count").tag(ConveyTaskManager.Sort.count)
				 Text("Size").tag(ConveyTaskManager.Sort.size)
				 Text("Date").tag(ConveyTaskManager.Sort.recent)
			 }
			 .pickerStyle(.segmented)
			 .padding()
			 
			 List(manager.types.indices, id: \.self) { index in
				 TaskTypeRow(taskType: $manager.types[index])
			 }
			 .listStyle(.plain)
			
			 HStack() {
				 Button("All Off") { manager.turnAllOff() }.padding()
					 .disabled(manager.areAllOff)
				 Button("Reset All") { manager.resetAll() }.padding()
				 Button("Reset Current") { manager.types.resetTaskTypes() }.padding()
			 }
		 }
		 .navigationBarTitle("Network Tasks")
    }
	
	struct TaskTypeRow: View {
		@Binding var taskType: ConveyTaskManager.TaskType
		
		var body: some View {
			Group {
				if taskType.hasStoredResults {
					NavigationLink(destination: TaskResultsListView(taskType: taskType)) { rowContent }
				} else {
					rowContent
				}
			}
			.id(taskType.taskName)
		}
		
		var rowContent: some View {
			HStack(spacing: 20) {
				VStack(spacing: 0) {
					Toggle("", isOn: $taskType.shouldEcho).labelsHidden()
					Text("echo")
						.font(.caption)
				}
				.opacity(taskType.manuallyEcho != nil ? 1 : 0.5)

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
struct TaskManagerView_Previews: PreviewProvider {
    static var previews: some View {
		 TaskManagerView()
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
