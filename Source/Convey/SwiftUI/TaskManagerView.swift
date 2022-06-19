//
//  TaskManagerView.swift
//  
//
//  Created by Ben Gottlieb on 6/18/22.
//

import SwiftUI

public struct TaskManagerView: View {
	@ObservedObject var manager = ConveyTaskManager.instance
	
	public init() { }
	
	public var body: some View {
		 VStack() {
			 List(manager.types.indices, id: \.self) { index in
				 TaskTypeRow(taskType: $manager.types[index])
			 }
			
			 HStack() {
				 Button("Reset All") { manager.resetAll() }.padding()
				 Button("Reset Current") { manager.resetCurrent() }.padding()
			 }
		 }
    }
	
	struct TaskTypeRow: View {
		@Binding var taskType: ConveyTaskManager.TaskType
		
		var body: some View {
			HStack(spacing: 10) {
				VStack(spacing: 0) {
					Toggle("", isOn: $taskType.echo).frame(width: 60)
					Text("echo")
						.font(.caption)
				}
				
				VStack(alignment: .leading) {
					Text(taskType.taskName)
						.font(.body)
					Text("This run: \(taskType.thisRunCount), total: \(taskType.totalCount)")
						.font(.caption)
				}
				Spacer()
			}
		}
	}
}

struct TaskManagerView_Previews: PreviewProvider {
    static var previews: some View {
		 TaskManagerView()
    }
}
