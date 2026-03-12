//
//  View+TaskObserving.swift
//  Convey
//
//  Created by Ben Gottlieb on 3/12/26.
//

import SwiftUI

@available(iOS 17, macOS 14, watchOS 10, *)
struct ObserveTaskModifier<Target: DownloadingTask>: ViewModifier {
	@State var token = ""
	var closure: @MainActor @Sendable (Target, Error?) -> Void
	
	func body(content: Content) -> some View {
		content
			.onAppear {
				token = TaskObserver.instance.register(Target.self, callback: closure)
			}
			.onDisappear {
				TaskObserver.instance.unregister(token: token)
			}
	}
}

@available(iOS 17, macOS 14, watchOS 10, *)
public extension View {
	@ViewBuilder func observeTask<Target: DownloadingTask>(_ type: Target.Type, callback: @MainActor @escaping (Target, Error?) -> Void) -> some View {
		self
			.modifier(ObserveTaskModifier(closure: callback))
	}
}
