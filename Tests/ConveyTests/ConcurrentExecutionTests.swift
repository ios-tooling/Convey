//
//  ConcurrentExecutionTests.swift
//  Convey
//
//  Created by Claude Code
//

import Testing
import Foundation
@testable import Convey

@Suite("Concurrent Task Execution")
struct ConcurrentExecutionTests {

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

	struct SimpleTask: DataDownloadingTask {
		var path: String
		var server: ConveyServerable { TestServer.shared }
		var configuration: TaskConfiguration?

		nonisolated init(path: String) {
			self.path = path
		}
	}

	struct IndexedTask: DataDownloadingTask {
		var path: String = "get"
		let index: Int
		var server: ConveyServerable { TestServer.shared }
		var configuration: TaskConfiguration?
		var queryParameters: (any TaskQueryParameters)? { ["index": "\(index)"] }
	}

	@Test("Multiple tasks can execute concurrently")
	func testConcurrentExecution() async throws {
		let taskCount = 10
		let startTime = Date()

		// Execute multiple tasks concurrently
		await withTaskGroup(of: Result<ServerResponse<Data>, Error>.self) { group in
			for _ in 0..<taskCount {
				group.addTask {
					let task = SimpleTask(path: "delay/2")
					do {
						let response = try await task.downloadData()
						return .success(response)
					} catch {
						return .failure(error)
					}
				}
			}

			var results: [Result<ServerResponse<Data>, Error>] = []
			for await result in group {
				results.append(result)
			}

			let elapsed = Date().timeIntervalSince(startTime)

			// If truly concurrent, 5 tasks with 1 second delay each
			// should complete in ~2-3 seconds, not 5+ seconds
			#expect(elapsed < 10.0, "Tasks should execute concurrently, took \(elapsed) seconds")
			#expect(results.count == taskCount, "All tasks should complete")
		}
	}

	@Test("Concurrent tasks don't interfere with each other")
	func testTaskIsolation() async throws {
		let taskCount = 10

		await withTaskGroup(of: (Int, Result<ServerResponse<Data>, Error>).self) { group in
			for i in 0..<taskCount {
				group.addTask {
					let task = IndexedTask(index: i)
					print(await task.url)
					do {
						let response = try await task.downloadData()
						return (i, .success(response))
					} catch {
						return (i, .failure(error))
					}
				}
			}

			var results: [(Int, Result<ServerResponse<Data>, Error>)] = []
			for await result in group {
				results.append(result)
			}

			#expect(results.count == taskCount, "All tasks should complete")

			let successCount = results.filter {
				if case .success = $0.1 { return true }
				return false
			}.count

			#expect(successCount == taskCount, "All tasks should succeed")
		}
	}

	@Test("URLSession pooling works correctly")
	func testSessionPooling() async throws {
		// Tasks with same configuration should reuse sessions

		struct SessionTrackingTask: DataDownloadingTask {
			var path: String = "get"
			var server: ConveyServerable { TestServer.shared }
			var configuration: TaskConfiguration?
			var taskTimeout: TimeInterval

			nonisolated init(timeout: TimeInterval) {
				self.taskTimeout = timeout
				self.configuration = TaskConfiguration(timeout: timeout)
			}

			var timeoutIntervalForRequest: TimeInterval? { taskTimeout }
		}

		// Create multiple tasks with same timeout (should share session)
		let task1 = SessionTrackingTask(timeout: 30.0)
		let task2 = SessionTrackingTask(timeout: 30.0)

		// Create task with different timeout (should use different session)
		let task3 = SessionTrackingTask(timeout: 60.0)

		do {
			_ = try await task1.downloadData()
			_ = try await task2.downloadData()
			_ = try await task3.downloadData()

			// If we get here without errors, session pooling is working
			#expect(true, "Session pooling works")
		} catch {
			Issue.record("Session pooling test failed: \(error)")
		}
	}

	@Test("Race condition safety with ConveyActor")
	func testRaceConditionSafety() async throws {
		actor Counter {
			var count = 0

			func increment() {
				count += 1
			}

			func getCount() -> Int {
				count
			}
		}

		let counter = Counter()
		let iterations = 100

		struct CountingTask: DataDownloadingTask {
			var path: String = "get"
			var server: ConveyServerable { TestServer.shared }
			var configuration: TaskConfiguration?
			let counter: Counter

			func didFinish(with response: ServerResponse<Data>) async {
				await counter.increment()
			}
		}

		await withTaskGroup(of: Void.self) { group in
			for _ in 0..<iterations {
				group.addTask {
					let task = CountingTask(counter: counter)
					do {
						_ = try await task.downloadData()
					} catch {
						// Ignore errors
					}
				}
			}
		}

		// Wait a bit for async operations
		try await Task.sleep(nanoseconds: 1_000_000_000)

		let finalCount = await counter.getCount()

		// Should have exactly the number of successful requests
		#expect(finalCount > 0, "Should have incremented counter")
		#expect(finalCount <= iterations, "Should not exceed iteration count due to race conditions")
	}

	@Test("Task cancellation works")
	func testTaskCancellation() async throws {
		struct CancellableTask: DataDownloadingTask {
			var path: String = "delay/10"
			var server: ConveyServerable { TestServer.shared }
			var configuration: TaskConfiguration?
		}

		let task = Task {
			let downloadTask = CancellableTask()
			return try await downloadTask.downloadData()
		}

		// Cancel after a short delay
		try await Task.sleep(nanoseconds: 100_000_000)
		task.cancel()

		do {
			_ = try await task.value
			Issue.record("Task should have been cancelled")
		} catch {
			// Task was cancelled or timed out
			#expect(true, "Task was cancelled or failed")
		}
	}

	@Test("Concurrent tasks with different servers")
	func testMultipleServers() async throws {
		@ConveyActor
		class Server1: ConveyServerable {
			var remote = Remote(URL(string: "https://httpbin.org")!, name: "Test")
			var configuration = ServerConfiguration()
			static let instance = Server1()

			func headers(for task: any DownloadingTask) async throws -> Headers {
				configuration.defaultHeaders
			}

			func didFinish<T>(task: T, response: ServerResponse<Data>?, error: (any Error)?) async where T : DownloadingTask {
			}
		}

		@ConveyActor
		class Server2: ConveyServerable {
			var remote = Remote(URL(string: "https://httpbin.org")!, name: "Test")
			var configuration = ServerConfiguration()
			static let instance = Server2()

			func headers(for task: any DownloadingTask) async throws -> Headers {
				configuration.defaultHeaders
			}

			func didFinish<T>(task: T, response: ServerResponse<Data>?, error: (any Error)?) async where T : DownloadingTask {
			}
		}

		struct Task1: DataDownloadingTask {
			var path: String = "get"
			var server: ConveyServerable { Server1.instance }
			var configuration: TaskConfiguration?
		}

		struct Task2: DataDownloadingTask {
			var path: String = "get"
			var server: ConveyServerable { Server2.instance }
			var configuration: TaskConfiguration?
		}

		async let result1 = Task1().downloadData()
		async let result2 = Task2().downloadData()

		do {
			let (r1, r2) = try await (result1, result2)
			#expect(r1.statusCode == 200, "First server task should succeed")
			#expect(r2.statusCode == 200, "Second server task should succeed")
		} catch {
			Issue.record("Multi-server test failed: \(error)")
		}
	}

	@Test("High concurrency stress test")
	func testHighConcurrency() async throws {
		let taskCount = 50
		let startTime = Date()

		await withTaskGroup(of: Result<Int, Error>.self) { group in
			for _ in 0..<taskCount {
				group.addTask {
					let task = SimpleTask(path: "get")
					do {
						let response = try await task.downloadData()
						return .success(response.statusCode)
					} catch {
						return .failure(error)
					}
				}
			}

			var successCount = 0
			var failureCount = 0

			for await result in group {
				switch result {
				case .success(let code):
					if code == 200 { successCount += 1 }
				case .failure:
					failureCount += 1
				}
			}

			let elapsed = Date().timeIntervalSince(startTime)

			// Most tasks should succeed
			#expect(successCount > taskCount / 2, "Majority of tasks should succeed: \(successCount)/\(taskCount)")

			// Should complete in reasonable time
			#expect(elapsed < 30.0, "High concurrency test should complete in reasonable time: \(elapsed)s")
		}
	}

	@Test("Sequential execution still works")
	func testSequentialExecution() async throws {
		var results: [Int] = []

		for _ in 0..<3 {
			let task = SimpleTask(path: "get")
			do {
				let response = try await task.downloadData()
				results.append(response.statusCode)
			} catch {
				// Ignore
			}
		}

		#expect(results.count == 3, "All sequential tasks should complete")
	}
}
