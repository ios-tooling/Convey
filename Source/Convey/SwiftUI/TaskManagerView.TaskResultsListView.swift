//
//  TaskResultsListView.swift
//  
//
//  Created by Ben Gottlieb on 6/19/22.
//

import SwiftUI

@available(watchOS, unavailable)
extension TaskManagerView {
	struct TaskResultsListView: View {
		let taskType: ConveyTaskManager.TaskType
		let urls: [URL]
		
		init(taskType: ConveyTaskManager.TaskType) {
			self.taskType = taskType
			self.urls = taskType.storedURLs.sorted { $0.absoluteString > $1.absoluteString }
		}
		
		var body: some View {
			List() {
				ForEach(urls, id: \.absoluteString) { url in
					NavigationLink(destination: TaskResultsDetails(url: url)) {
						Text(url.lastPathComponent)
					}
				}
			}
			.listStyle(.plain)
			.navigationBarTitle(taskType.name)
		}
	}
}
