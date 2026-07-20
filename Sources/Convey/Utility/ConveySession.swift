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
	var request: URLRequest
	let ungzippedRequest: URLRequest?
	private var isFinished = false
	var requestID: String? { task.requestID }
	var taskType: any DownloadingTask.Type { type(of: task) }
	
	nonisolated public func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}
	
	nonisolated public static func ==(lhs: ConveySession, rhs: ConveySession) -> Bool {
		lhs.id == rhs.id
	}
	
	static func session(for requestID: String) -> ConveySession? {
		activeSessions.value.first { $0.requestID == requestID }
	}
	
	static func cancel(sessionWithRequestID requestID: String) {
		session(for: requestID)?.cancel()
	}
	
	static func sessions(withType type: any DownloadingTask.Type) -> [ConveySession] {
		activeSessions.value.filter { $0.taskType == type }
	}
	
	static let activeSessions = ConveyThreadsafeMutex<Set<ConveySession>>([])
	
	@ConveyActor public init<Task: DownloadingTask>(server: ConveyServerable, task: Task) async throws {
		do {
			self.server = server
			self.task = task
			self.request = try await task.request
			self.ungzippedRequest = task.shouldGZIPUploads ? try await task.gzipped(false).request : nil
			
			// Copy the server-provided configuration so per-task tweaks
			// (timeouts, expensive-network policy) don't mutate the shared
			// template. Callers can plug in `.ephemeral` or any other variant
			// via `server.configuration.urlSessionConfiguration`.
			let baseConfig = server.configuration.urlSessionConfiguration
			let configuration = (baseConfig.copy() as? URLSessionConfiguration) ?? URLSessionConfiguration.default
			let taskConfig = task.configuration
			
			if let expensive = task.allowsExpensiveNetworkAccess { configuration.allowsExpensiveNetworkAccess = expensive }
			if let constrained = task.allowsConstrainedNetworkAccess { configuration.allowsConstrainedNetworkAccess = constrained }
			configuration.timeoutIntervalForRequest = task.timeoutIntervalForRequest ?? taskConfig?.timeout ?? server.configuration.defaultTimeout
			
			configuration.timeoutIntervalForResource = task.timeoutIntervalForResource ?? taskConfig?.timeout ?? server.configuration.defaultTimeout
			
			self.session = URLSession(configuration: configuration, delegate: SharedURLSessionDelegate.instance, delegateQueue: server.downloadQueue)
		} catch {
			throw error
		}
	}
	
	func start() {
		Self.activeSessions.perform { $0.insert(self) }
	}
	
	func cancel() {
		guard !isFinished else { return }
		isFinished = true
		session.invalidateAndCancel()
		Self.activeSessions.perform { $0.remove(self) }
	}
	
	func finish() {
		guard !isFinished else { return }
		isFinished = true
		Self.activeSessions.perform { $0.remove(self) }
		session.finishTasksAndInvalidate()
	}
	
}

extension ConveySession {
	func fetchData() async throws -> (Data, URLResponse, Int, Error?) {
		var attemptNumber = 0

		while true {
			do {
				let (data, response): (Data, URLResponse)
				if let requiredInterface = server.configuration.requiredNetworkInterface {
					(data, response) = try await NetworkInterfaceHTTPClient(requiredInterface: requiredInterface).data(for: request)
				} else {
					(data, response) = try await session.data(for: request)
				}
				// A throwing HTTP status (4xx/5xx by default) consults the task's
				// retryInterval just like a transport error, so rate limits and
				// server hiccups back off and retry in one place.
				if let httpError = HTTPError.withResponse(response, data: data, throwingStatusCategories: task.throwingStatusCategories) {
					attemptNumber += 1
					if let delay = task.retryInterval(afterError: httpError, count: attemptNumber) {
						try await retryDelay(delay)
						continue
					}
					return (data, response, attemptNumber, httpError)
				}
				return (data, response, attemptNumber + 1, nil)
			} catch let error {
				attemptNumber += 1
				if let delay = task.retryInterval(afterError: error, count: attemptNumber) {
					try await retryDelay(delay)
					continue
				}
				guard let urlError = error as? URLError else { throw error }
				guard urlError.code == .timedOut else { throw error }
				throw URLError(.timedOut)
			}
		}
	}

	private func retryDelay(_ delay: TimeInterval) async throws {
		if #available(iOS 16.0, macOS 13, *) {
			try await Task.sleep(for: .seconds(delay))
		} else {
			try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
		}
	}
}

final class SharedURLSessionDelegate: NSObject, URLSessionDelegate {
	static let instance = SharedURLSessionDelegate()
}
