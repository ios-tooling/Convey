//
//  TaskRow.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/25/25.
//

import SwiftUI

@available(iOS 18, macOS 15, watchOS 10, *)
extension RecordedTasksScreen.TaskList {
	struct TaskRow: View {
		let task: RecordedTask
		static let formatter: ByteCountFormatter = {
			let formatter = ByteCountFormatter()
			formatter.isAdaptive = true
			return formatter
		}()

		var body: some View {
			VStack(alignment: .leading) {
				HStack {
					let isDelete = task.method == "DELETE"
										
					Text(task.method)
						.padding(2)
						.padding(.horizontal, 4)
						.font(.system(size: 12))
						.background { RoundedRectangle(cornerRadius: 4).fill((isDelete ? Color.red : Color.gray).opacity(0.4)) }
					
					if let statusCode = task.statusCode, statusCode / 100 != 2 {
						Text("\(statusCode)")
							.foregroundStyle(.black)
							.padding(.horizontal, 4)
							.font(.system(size: 12))
							.background { RoundedRectangle(cornerRadius: 4).fill(.orange) }
					}
					
					Text(task.name).bold()
						.font(.system(size: 13))
					Spacer()
					
					if task.wasCancelled {
						Text("🚫")
					} else if task.timedOut {
						Text("⏰ \(task.timeoutDuration.formatted())")
					} else if task.error != nil {
						Text("⚠️")
					}
					sizeWidget
				}
				
				if let url = task.url {
					let prefix = (url.scheme ?? "") + "://" + (url.host() ?? "")
					
					Text(url.absoluteString.dropFirst(prefix.count))
						.font(.system(size: 11))
				}
				
				HStack {
					Text(task.startedAt.formatted(date: .abbreviated, time: .complete))
					Spacer()
					if let duration = task.duration {
						Text("\(duration.formatted(.number.precision(.fractionLength(2))))s")
							.bold()
					}
				}
				.font(.system(size: 10))
				.opacity(0.6)
			}
		}
		
		func byteString(from count: Int) -> String {
			let string = Self.formatter.string(fromByteCount: Int64(count))
			
			return string.replacingOccurrences(of: "bytes", with: "b")
		}
		
		@ViewBuilder var sizeWidget: some View {
			let upSize = task.uploadSize
			let downSize = task.downloadSize
			let darkTextColor = Color.primary
			let darkColor = darkTextColor.opacity(0.4)
			#if os(macOS)
				let lightColor = Color(nsColor: .textBackgroundColor)
			#else
				let lightColor = Color(uiColor: .systemBackground)
			#endif
			
			if upSize != nil || downSize != nil {
				HStack(spacing: 0) {
					if let upSize {
						Text(byteString(from: upSize))
							.padding(4)
							.padding(.horizontal, 6)
							.font(.system(size: 12))
							.foregroundStyle(darkColor)
					}

					if let downSize {
						Text(byteString(from: downSize))
							.padding(4)
							.padding(.horizontal, 6)
							.font(.system(size: 12))
							.foregroundStyle(lightColor)
							.background { RoundedRectangle(cornerRadius: 4).fill(darkColor) }
							
					}
				}
				.lineLimit(1)
				.background { RoundedRectangle(cornerRadius: 4).stroke(darkColor) }
			}
		}
	}
}
