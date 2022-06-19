//
//  TaskManagerView.swift
//  
//
//  Created by Ben Gottlieb on 6/18/22.
//

import SwiftUI

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
			 }
			 .pickerStyle(.segmented)
			 
			 List(manager.types.indices, id: \.self) { index in
				 TaskTypeRow(taskType: $manager.types[index])
			 }
			 .listStyle(.plain)
			
			 HStack() {
				 Button("Reset All") { manager.resetAll() }.padding()
				 Button("Reset Current") { manager.resetCurrent() }.padding()
			 }
		 }
		 .navigationBarTitle("Network Tasks")
    }
	
	struct TaskTypeRow: View {
		@Binding var taskType: ConveyTaskManager.TaskType
		
		var body: some View {
			HStack(spacing: 20) {
				VStack(spacing: 0) {
					Toggle("", isOn: $taskType.echo).labelsHidden()
					Text("echo")
						.font(.caption)
				}
				
				VStack(alignment: .leading) {
					Text(taskType.name)
						.font(.body)
					Text("This run: \(taskType.thisRunBytesString) (\(taskType.thisRunCount))")
						.font(.caption)
					Text("Total: \(taskType.totalBytesString) (\(taskType.totalCount))")
						.font(.caption)
				}
				Spacer()
			}
			.id(taskType.taskName)
		}
	}
}

@available(watchOS, unavailable)
struct TaskManagerView_Previews: PreviewProvider {
    static var previews: some View {
		 TaskManagerView()
    }
}
