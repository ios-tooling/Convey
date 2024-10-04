//
//  ActiveSessions.swift
//  Convey
//
//  Created by Ben Gottlieb on 10/4/24.
//

import Foundation
import Combine

actor ActiveSessions {
	let sessions: CurrentValueSubject<Set<ConveySession>, Never> = .init([])
	
	nonisolated var isEmpty: Bool { sessions.value.isEmpty }
	
	func insert(_ session: ConveySession) {
		var value = sessions.value
		value.insert(session)
		sessions.send(value)
	}
	
	func remove(_ session: ConveySession) {
		var value = sessions.value
		value.remove(session)
		sessions.send(value)
	}
}
