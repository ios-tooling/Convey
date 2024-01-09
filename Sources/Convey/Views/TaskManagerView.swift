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
				 Text("On").tag(ConveyTaskManager.Sort.enabled)
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
					 .disabled(!manager.canResetAll)
				 Button("Reset Current") { manager.types.resetTaskTypes() }.padding()
			 }
		 }
		 .navigationBarTitle("Network Tasks")
    }
	
	struct TaskTypeRow: View {
		@Binding var taskType: ConveyTaskManager.LoggedTaskInfo
		
		var body: some View {
			Group {
				if taskType.hasStoredResults {
					ZStack() {
						NavigationLink(destination: TaskResultsListView(taskType: taskType)) { rowContent }.opacity(0.5)
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
					Button(action: { taskType.shouldEcho.toggle() }) {
						Text("Echo")
							.font(.system(size: 12, weight: .bold).smallCaps())
							.padding(.vertical, 5)
							.padding(.horizontal, 10)
							.foregroundColor(taskType.shouldEcho ? .white : .blue)
							.background(Capsule().fill(taskType.shouldEcho ? .blue : .white))
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
