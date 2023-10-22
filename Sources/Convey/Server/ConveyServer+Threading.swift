//
//  ConveyServer+Threading.swift
//  ConveyTest_iOS
//
//  Created by Ben Gottlieb on 5/22/22.
//

import Foundation

typealias EmptyContinuation = UnsafeContinuation<Void, Never>

extension ConveyServer {
	func wait(forThread threadName: String?) async {
		guard let threadName else { return }
		await threadManager.wait(forThread: threadName)
	}
	
	func stopWaiting(forThread threadName: String?) async {
		guard let threadName else { return }
		await threadManager.stopWaiting(forThread: threadName)
	}
}

actor ThreadManager {
	var continuations: [String: [EmptyContinuation]] = [:]
	var active: [String: Bool] = [:]
	
	func fetchContinuations(for name: String) -> [EmptyContinuation] { self.continuations[name] ?? [] }
	func setContinuations(_ cont: [EmptyContinuation], for name: String) {
		self.continuations[name] = cont
	}
	
	func wait(forThread threadName: String) async {
		if self.active[threadName] != true {
			self.active[threadName] = true
			return
		}
		
		let _: Void = await withUnsafeContinuation { continuation in
			let current = fetchContinuations(for: threadName)
			setContinuations(current + [continuation], for: threadName)
		}
	}
	
	func stopWaiting(forThread threadName: String) {
		let currentContinuations = self.continuations[threadName] ?? []
		if let first = currentContinuations.first {
			self.continuations[threadName] = Array(currentContinuations.dropFirst())
			first.resume()
		} else {
			self.active[threadName] = false
		}
	}
}
