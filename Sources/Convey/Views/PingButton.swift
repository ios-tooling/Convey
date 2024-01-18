//
//  PingButton.swift
//
//
//  Created by Ben Gottlieb on 1/18/24.
//

import SwiftUI


@available(iOS 14.0, macOS 12, watchOS 8, *)
public struct PingButton<TaskKind: ServerTask>: View {
	let target: TaskKind
	@State private var lastDuration: TimeInterval?
	@State private var error: Error?
	@State private var isRunning = false
	
	var color: Color {
		if lastDuration != nil { return .green }
		if error != nil { return .red }
		return .yellow
	}
	
	public init(_ target: TaskKind) {
		self.target = target
	}
	
	func ping() {
		isRunning = true
		Task {
			do {
				lastDuration = try await target.ping()
			} catch {
				lastDuration = nil
				self.error = error
			}
			isRunning = false
		}
	}
	
	public var body: some View {
		Group {
			Button(action: { ping() }) {
				if isRunning {
					ProgressView()
				} else {
					Circle()
						.fill(color)
						.frame(width: 20, height: 20)
				}
			}
		}
	}
}
