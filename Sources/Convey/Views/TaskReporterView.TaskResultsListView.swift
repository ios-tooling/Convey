//
//  TaskReporter.swift
//  
//
//  Created by Ben Gottlieb on 6/19/22.
//

import SwiftUI

#if canImport(UIKit)

@available(watchOS, unavailable)
extension TaskReporterView {
	@MainActor struct TaskResultsListView: View {
		let taskType: ConveyTaskReporter.LoggedTaskInfo
		let urls: [URL]
		let manager: ConveyTaskReporter
		
		init(taskType: ConveyTaskReporter.LoggedTaskInfo, manager: ConveyTaskReporter) {
			self.taskType = taskType
			self.manager = manager
			self.urls = taskType.storedURLs(for: manager).sorted { $0.absoluteString > $1.absoluteString }
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
#endif
