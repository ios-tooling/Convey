//
//  TaskRecovery.swift
//  Convey
//
//  Created by Ben Gottlieb on 4/15/26.
//

import Foundation

struct RetryCallback {
	var retryCallback: (() async -> Void)
	let id: String
}

@available(iOS 17, macOS 14, watchOS 10, *)
public actor TaskRecovery {
	public static let instance = TaskRecovery()
	
	var retryCallbacks: [RetryCallback] = []
	var storableTaskTypes: [String: any StorableTask.Type] = [:]
	
	public func retryAllFailedTasks() async {
		for callback in retryCallbacks {
			await callback.retryCallback()
		}
	}
	
}
