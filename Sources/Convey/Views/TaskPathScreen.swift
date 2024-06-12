//
//  TaskPathScreen.swift
//
//
//  Created by Ben Gottlieb on 6/8/24.
//

import SwiftUI

@available(iOS 16.0, macOS 13, *)
public struct TaskPathScreen: View {
	@ObservedObject var path: TaskPath
	
	public init(path: TaskPath) {
		self.path = path
	}
	
	public var body: some View {
		NavigationStack {
			VStack {
				List {
					ForEach(path.urls) { url in
						NavigationLink(value: url) {
							VStack(alignment: .leading) {
								Text(url.fileURL.deletingPathExtension().lastPathComponent)
								if let url = url.url {
									Text(url.absoluteString)
										.font(.caption2)
								}
								Text(url.date.formatted())
									.font(.caption)
							}
							.opacity(url.fromDisk ? 0.45 : 1.0)
							.contentShape(.rect)
						}
					}
				}
			}
			.navigationDestination(for: TaskPath.TaskRecording.self) { recording in
				if let text = try? String(contentsOf: recording.fileURL) {
					ScrollView {
						Text(text)
					}
				}
			}
			.toolbar {
				ToolbarItem(placement: .bottomBar) {
					Button("Clear Recordings") {
						Task { await path.clear() }
					}
					.buttonStyle(.bordered)
				}
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}
}
