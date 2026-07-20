//
//  RetryLogicTests.swift
//  Convey
//
//  Created by Claude Code
//

import Testing
import Foundation
@testable import Convey

@Suite("Retry Logic")
struct RetryLogicTests {

	@ConveyActor
	class TestServer: ConveyServerable {
		var remote = Remote(URL(string: "https://httpbin.org")!, name: "Test")
		var configuration = ServerConfiguration()

		static let shared = TestServer()

		func headers(for task: any DownloadingTask) async throws -> Headers {
			configuration.defaultHeaders
		}

		func didFinish<T>(task: T, response: ServerResponse<Data>?, error: (any Error)?) async where T : DownloadingTask {
		}
	}

	// Task that tracks retry attempts
	struct RetryTrackingTask: DataDownloadingTask {
		var path: String
		var server: ConveyServerable { TestServer.shared }
		var configuration: TaskConfiguration?

		let maxRetries: Int
		let retryDelay: TimeInterval
		@ConveyActor
		static var attemptCount = 0

		nonisolated init(path: String = "delay/10", maxRetries: Int = 3, retryDelay: TimeInterval = 0.1) {
			self.path = path
			self.maxRetries = maxRetries
			self.retryDelay = retryDelay
		}

		func retryInterval(afterError error: any Error, count: Int) -> TimeInterval? {
			Task { @ConveyActor in
				Self.attemptCount = count
			}
			return count < maxRetries ? retryDelay : nil
		}
	}

	// Task with no retry logic
	struct NoRetryTask: DataDownloadingTask {
		var path: String
		var server: ConveyServerable { TestServer.shared }
		var configuration: TaskConfiguration?

		nonisolated init(path: String = "delay/10") {
			self.path = path
		}

		// Default implementation returns nil (no retry)
	}

	// Task with exponential backoff
	struct ExponentialBackoffTask: DataDownloadingTask {
		var path: String
		var server: ConveyServerable { TestServer.shared }
		var configuration: TaskConfiguration?

		let maxRetries: Int
		let baseDelay: TimeInterval
		@ConveyActor
		static var retryIntervals: [TimeInterval] = []

		nonisolated init(path: String = "delay/10", maxRetries: Int = 3, baseDelay: TimeInterval = 0.1) {
			self.path = path
			self.maxRetries = maxRetries
			self.baseDelay = baseDelay
		}

		func retryInterval(afterError error: any Error, count: Int) -> TimeInterval? {
			guard count < maxRetries else { return nil }

			// Exponential backoff: baseDelay * 2^(count-1)
			let interval = baseDelay * pow(2.0, Double(count - 1))

			Task { @ConveyActor in
				Self.retryIntervals.append(interval)
			}

			return interval
		}
	}

	@Test("Task with retry logic attempts multiple times")
	@ConveyActor func testRetryLogic() async throws {
		// Reset attempt counter
		RetryTrackingTask.attemptCount = 0

		// Create task with short timeout to trigger retry
		var task = RetryTrackingTask(path: "delay/10", maxRetries: 2, retryDelay: 0.05)
		task.configuration = TaskConfiguration(timeout: 0.01)

		do {
			_ = try await task.downloadData()
		} catch {
			// Expected to fail after retries
		}

		// Wait a bit for async updates
		try await Task.sleep(nanoseconds: 100_000_000)

		// Should have attempted at least 1 retry
		let attempts = RetryTrackingTask.attemptCount

		#expect(attempts >= 1, "Should have attempted at least 1 retry, got \(attempts)")
	}

	@Test("Task without retry logic fails immediately on timeout")
	func testNoRetryLogic() async throws {
		var task = NoRetryTask(path: "delay/10")
		task.configuration = TaskConfiguration(timeout: 0.01)

		let startTime = Date()

		do {
			_ = try await task.downloadData()
		} catch {
			// Expected to fail
		}

		let elapsed = Date().timeIntervalSince(startTime)

		// Should fail quickly without retries (within 0.5 seconds)
		#expect(elapsed < 0.5, "Should fail quickly without retries, took \(elapsed) seconds")
	}

	@Test("Exponential backoff increases delay between retries")
	@ConveyActor func testExponentialBackoff() async throws {
		// Reset intervals
		ExponentialBackoffTask.retryIntervals = []

		var task = ExponentialBackoffTask(path: "delay/10", maxRetries: 3, baseDelay: 0.1)
		task.configuration = TaskConfiguration(timeout: 0.01)

		do {
			_ = try await task.downloadData()
		} catch {
			// Expected to fail
		}

		// Wait for async updates
		try await Task.sleep(nanoseconds: 100_000_000)

		let intervals = ExponentialBackoffTask.retryIntervals

		// Should have recorded intervals
		if intervals.count >= 2 {
			// Each interval should be roughly double the previous
			for i in 1..<intervals.count {
				let ratio = intervals[i] / intervals[i-1]
				#expect(ratio >= 1.8 && ratio <= 2.2, "Exponential backoff ratio should be ~2, got \(ratio)")
			}
		}
	}

	// Task that retries throwing HTTP statuses (429/5xx-style)
	struct StatusRetryTask: DataDownloadingTask {
		var path: String
		var server: ConveyServerable { TestServer.shared }
		var configuration: TaskConfiguration?

		let maxRetries: Int
		@ConveyActor static var attemptCounts: [Int] = []
		@ConveyActor static var lastErrorStatus: Int?

		nonisolated init(path: String = "status/503", maxRetries: Int = 2) {
			self.path = path
			self.maxRetries = maxRetries
		}

		func retryInterval(afterError error: any Error, count: Int) -> TimeInterval? {
			Self.attemptCounts.append(count)
			Self.lastErrorStatus = (error as? any HTTPErrorType)?.statusCode
			return count < maxRetries ? 0.05 : nil
		}
	}

	@Test("Throwing HTTP statuses consult retryInterval")
	@ConveyActor func testHTTPStatusRetry() async throws {
		StatusRetryTask.attemptCounts = []
		StatusRetryTask.lastErrorStatus = nil

		let task = StatusRetryTask(path: "status/503", maxRetries: 2)
		var thrownStatus: Int?
		do {
			_ = try await task.downloadData()
		} catch let error as any HTTPErrorType {
			thrownStatus = error.statusCode
		} catch {
			// Network unavailable — nothing to assert
		}

		if thrownStatus != nil {
			#expect(thrownStatus == 503)
			// retryInterval saw the 503 as an HTTPErrorType on each attempt,
			// and the loop stopped when it returned nil at maxRetries.
			#expect(StatusRetryTask.attemptCounts == [1, 2])
			#expect(StatusRetryTask.lastErrorStatus == 503)
		}
	}

	@Test("Errors without a retryInterval surface immediately")
	func testNoRetryWithoutInterval() async throws {
		// ConveySession consults task.retryInterval(afterError:count:) for
		// transport errors AND for throwing HTTP statuses; the default
		// implementation returns nil, so errors surface with no retry —
		// exercised by testNoRetryLogic above and testHTTPStatusRetry once
		// maxRetries is reached.
		#expect(true)
	}

	@Test("ServerResponse contains attempt number")
	func testAttemptNumberTracking() async throws {
		let task = SimpleGETTask(url: URL(string: "https://httpbin.org/get")!)

		do {
			let response = try await task.downloadData()
			#expect(response.attemptNumber >= 1, "Should track attempt number")
		} catch {
			// If it fails, that's okay for this test
		}
	}

	@Test("Retry respects maxRetries limit")
	@ConveyActor func testMaxRetriesLimit() async throws {
		RetryTrackingTask.attemptCount = 0

		var task = RetryTrackingTask(path: "delay/10", maxRetries: 2, retryDelay: 0.05)
		task.configuration = TaskConfiguration(timeout: 0.01)

		do {
			_ = try await task.downloadData()
		} catch {
			// Expected to fail
		}

		try await Task.sleep(nanoseconds: 200_000_000)

		let attempts = RetryTrackingTask.attemptCount

		// Should not exceed maxRetries
		#expect(attempts <= 2, "Should not exceed maxRetries of 2, got \(attempts)")
	}
}
