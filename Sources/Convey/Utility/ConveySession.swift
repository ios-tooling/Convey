//
//  ConveySession.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/19/25.
//

import Foundation

@ConveyActor final public class ConveySession: Hashable, Equatable {
	nonisolated let id = UUID()
	let server: ConveyServerable
	var session: URLSession = .shared
	let task: any DownloadingTask
	let request: URLRequest
	let ungzippedRequest: URLRequest?
	var tag: String? { task.requestTag }
	
	nonisolated public func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}
	
	nonisolated public static func ==(lhs: ConveySession, rhs: ConveySession) -> Bool {
		lhs.id == rhs.id
	}
	
	static func session(for tag: String) -> ConveySession? {
		activeSessions.value.first { $0.tag == tag }
	}
	
	static func cancel(sessionWithTag tag: String) {
		session(for: tag)?.cancel()
	}
	
	static let activeSessions = ConveyThreadsafeMutex<Set<ConveySession>>([])
	
	public init<Task: DownloadingTask>(server: ConveyServerable, task: Task) async throws {
		do {
			self.server = server
			self.task = task
			self.request = try await task.request
			self.ungzippedRequest = task.shouldGZIPUploads ? try await task.gzipped(false).request : nil
			
			let configuration = URLSessionConfiguration.default
			let taskConfig = task.configuration
			
			if let expensive = task.allowsExpensiveNetworkAccess { configuration.allowsExpensiveNetworkAccess = expensive }
			if let constrained = task.allowsConstrainedNetworkAccess { configuration.allowsConstrainedNetworkAccess = constrained }
			configuration.timeoutIntervalForRequest = task.timeoutIntervalForRequest ?? taskConfig?.timeout ?? server.configuration.defaultTimeout
			
			configuration.timeoutIntervalForResource = task.timeoutIntervalForResource ?? taskConfig?.timeout ?? server.configuration.defaultTimeout
			
			if let session = Self.activeSessions.value.first(where: { $0.session.hasSameConfiguration(as: configuration)}) {
				self.session = session.session
				return
			}

			self.session = URLSession(configuration: configuration, delegate: SharedURLSessionDelegate.instance, delegateQueue: server.downloadQueue)
		} catch {
			throw error
		}
	}
	
	func start() {
		Self.activeSessions.perform { $0.insert(self) }
	}
	
	func cancel() {
		session.invalidateAndCancel()
		finish()
	}
	
	func finish() {
		Self.activeSessions.perform { $0.remove(self) }
	}
}

extension ConveySession {
	func fetchData() async throws -> (Data, URLResponse, Int) {
		var attemptNumber = 0
		
		while true {
			do {
				let (data, response) = try await session.data(for: request)
				return (data, response, attemptNumber + 1)
			} catch let error as URLError {
				if error.code != .timedOut { throw error }
				attemptNumber += 1
				guard let delay = task.retryInterval(afterError: error, count: attemptNumber) else { break }
				if #available(iOS 16.0, macOS 13, *) {
					try await Task.sleep(for: .seconds(delay))
				} else {
					try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
				}
			} catch {
				throw error
			}
		}
		throw URLError(.timedOut)
	}
}

final class SharedURLSessionDelegate: NSObject, URLSessionDelegate {
	static let instance = SharedURLSessionDelegate()
}
