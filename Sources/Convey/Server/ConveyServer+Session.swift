//
//  ConveyServer+Session.swift
//
//
//  Created by Ben Gottlieb on 10/16/23.
//

import Foundation

extension ConveyServer {
	func register(session: ConveySession) {
		activeSessions.insert(session)
	}
	
	func unregister(session: ConveySession) {
		activeSessions.remove(session)
	}
	
	public func cancelTasks(with tags: [String]) async {
		for session in activeSessions {
			let allTasks = await session.session.allTasks
			
			for task in allTasks {
				if let tag = task.originalRequest?.requestTag, tags.contains(tag) {
					task.cancel()
				}
			}
		}
	}
}
