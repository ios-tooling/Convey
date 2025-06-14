//
//  TaskPathScreen.swift
//
//
//  Created by Ben Gottlieb on 6/8/24.
//

import SwiftUI

@available(iOS 16.0, macOS 13, watchOS 9, *)
public struct TaskPathScreen: View {
	@ObservedObject var path: TaskPath
	@State private var navPath = NavigationPath()
	@Environment(\.dismiss) var dismiss
	
	public init(path: TaskPath) {
		self.path = path
	}
	
	func show(_ task: TaskPath.TaskRecording) {
		navPath.append(task)
	}
	
	public var body: some View {
		NavigationStack(path: $navPath) {
			VStack {
				List {
					ForEach(path.urls) { url in
						Button(action: { show(url) }) {
							VStack(alignment: .leading) {
								Text(url.fileURL.deletingPathExtension().lastPathComponent)
								if let url = url.url {
									Text(url.absoluteString)
										.font(.caption2)
								}
								HStack {
									Text(url.date.formatted())
									Spacer()
									if let size = url.payloadSize {
										Text(ByteCountFormatter().string(fromByteCount: size))
											.bold()
									}
									if let duration = url.duration {
										Text(duration.formatted() + " s")
									}
								}
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
							.padding()
							.font(.caption.monospaced())
					}
				}
			}
			.toolbar {
				#if os(iOS)
					ToolbarItem(placement: .bottomBar) {
						Button("Clear Recordings (\(path.displayedCount))") {
							Task {
								await path.clear()
								dismiss()
							}
						}
						.buttonStyle(.bordered)
					}
				#endif
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}
}
