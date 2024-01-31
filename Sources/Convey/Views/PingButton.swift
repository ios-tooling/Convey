//
//  PingButton.swift
//
//
//  Created by Ben Gottlieb on 1/18/24.
//

import SwiftUI
import Combine

@available(iOS 14.0, macOS 12, watchOS 8, *)
public struct PingButton<TaskKind: ServerTask, Content: View>: View {
	let target: TaskKind
	@State private var lastDuration: TimeInterval?
	@State private var error: Error?
	@State private var isRunning = false
	let frequency: TimeInterval?
	let timer: Publishers.Autoconnect<Timer.TimerPublisher>
	@ViewBuilder var contentBuilder: (AnyView) -> Content
	@Environment(\.scenePhase) var scenePhase
	
	var color: Color {
		if lastDuration != nil { return .green }
		if error != nil { return .red }
		return .clear
	}
	
	public init(_ target: TaskKind, frequency: TimeInterval? = nil, @ViewBuilder content: @escaping (AnyView) -> Content) {
		self.target = target
		self.frequency = frequency
		timer = Timer.publish(every: frequency ?? 10000000, on: .main, in: .common).autoconnect()
		contentBuilder = content
	}
	
	func ping() {
		if isRunning { return }
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
	
	@ViewBuilder var indicator: some View {
		if isRunning {
			ProgressView()
		} else {
			ZStack {
				Circle()
					.fill(color)
				Circle()
					.stroke(.black)
			}
			.frame(width: 20, height: 20)
		}
	}
	
	public var body: some View {
		Button(action: { ping() }) {
			contentBuilder(AnyView(indicator))
		}
		.onReceive(timer) { _ in
			ping()
		}
		#if os(visionOS)
			.onChange(of: frequency) { _, newFreq in if newFreq != frequency, newFreq != nil { ping() }}
			.onChange(of: scenePhase) { _, newPhase in if frequency != nil, newPhase == .active { ping() } }
		#else
			.onChange(of: frequency) { newFreq in if newFreq != frequency, newFreq != nil { ping() }}
			.onChange(of: scenePhase) { newPhase in if frequency != nil, newPhase == .active { ping() } }
		#endif
		.onAppear { if frequency != nil { ping() }}
	}
}

@available(iOS 14.0, macOS 12, watchOS 8, *)
extension PingButton where Content == HStack<TupleView<(Text, AnyView)>> {
	public init(_ target: TaskKind, title: String, frequency: TimeInterval? = nil) {
		self.init(target, frequency: frequency) { indicator in
			HStack {
				Text(title)
				indicator
			}
		}
	}
}
