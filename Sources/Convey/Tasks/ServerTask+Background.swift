//
//  ServerTask+Background.swift
//  
//
//  Created by Ben Gottlieb on 4/29/24.
//

import Foundation
#if os(iOS)
import UIKit
#endif

extension ServerTask {
#if os(iOS)
	@MainActor func requestBackgroundTime() async -> UIBackgroundTaskIdentifier? {
		server.application?.beginBackgroundTask(withName: "") {  }
	}
	@MainActor func finishBackgroundTime(_ token: UIBackgroundTaskIdentifier?) {
		guard let token else { return }
		server.application?.endBackgroundTask(token)
	}
#else
	func requestBackgroundTime() async -> Int { 0 }
	func finishBackgroundTime(_ token: Int) async { }
#endif
	
	func handleThreadAndBackgrounding<Result: Sendable>(closure: () async throws -> Result) async throws -> Result {
		let oneOffLogging = await isOneOffLogged
		
		await server.wait(forThread: (self.wrappedTask as? ThreadedServerTask)?.threadName)
		let token = await requestBackgroundTime()
		let result = try await closure()
		await finishBackgroundTime(token)
		await server.stopWaiting(forThread: (self.wrappedTask as? ThreadedServerTask)?.threadName)
		if oneOffLogging { await server.taskManager.decrementOneOffLog(for: self) }
		return result
	}
}
