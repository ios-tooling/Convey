//
//  TaskManagerView.swift
//  
//
//  Created by Ben Gottlieb on 6/18/22.
//

import SwiftUI

#if canImport(UIKit)
@available(watchOS, unavailable)
@MainActor public struct TaskManagerView: View {
	@ObservedObject private var manager: ConveyTaskManager
	@State private var sort: ConveyTaskManager.Sort
	
	public init(server: ConveyServer = ConveyServer.serverInstance) {
		manager = server.taskManager
		sort = server.taskManager.sort.value
	}
	
	public var body: some View {
		 VStack() {
			 Picker("", selection: $sort.animation()) {
				 Text("Alpha").tag(ConveyTaskManager.Sort.alpha)
				 Text("Count").tag(ConveyTaskManager.Sort.count)
				 Text("Size").tag(ConveyTaskManager.Sort.size)
				 Text("Date").tag(ConveyTaskManager.Sort.recent)
				 Text("On").tag(ConveyTaskManager.Sort.enabled)
			 }
			 .pickerStyle(.segmented)
			 .padding()
			 
			 let types = manager.sortedTypes
			 List(types.indices, id: \.self) { index in
				 TaskTypeRow(taskType: types[index], manager: manager)
			 }
			 .listStyle(.plain)
			
			 HStack() {
				 Button("All Off") { manager.turnAllOff() }.padding()
					 .disabled(manager.areAllOff)
				 Button("Reset All") { manager.resetAll() }.padding()
					 .disabled(!manager.canResetAll)
				 
				 //#FIXME
				 //Button("Reset Current") { sortedTypes.resetTaskTypes(for: manager) }.padding()
			 }
		 }
		 .navigationBarTitle("Network Tasks")
		 .onChange(of: sort) { newValue in
			 Task { @MainActor in
				 await manager.updateSort(by: newValue)
				 manager.objectWillChange.send()
			 }
		 }
    }
	
	struct TaskTypeRow: View {
		var taskType: ConveyTaskManager.LoggedTaskInfo
		let manager: ConveyTaskManager
		
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
						//#FIXME
						//	taskType.setShouldEcho(!taskType.shouldEcho(nil, for: manager))
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
struct TaskManagerView_Previews: PreviewProvider {
    static var previews: some View {
		 TaskManagerView(server: ConveyServer.serverInstance)
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
