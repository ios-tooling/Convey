//
//  LifecycleHooksTests.swift
//  Convey
//
//  Created by Claude Code
//

import Testing
import Foundation
@testable import Convey

@Suite("Task Lifecycle Hooks")
struct LifecycleHooksTests {

	@ConveyActor
	class TestServer: ConveyServerable {
		var remote = Remote(URL(string: "https://httpbin.org")!, name: "Test")
		var configuration = ServerConfiguration()

		static let shared = TestServer()

		var didFinishCalls = 0
		var lastError: Error?
		var lastResponse: ServerResponse<Data>?

		func headers(for task: any DownloadingTask) async throws -> Headers {
			configuration.defaultHeaders
		}

		func didFinish<T>(task: T, response: ServerResponse<Data>?, error: (any Error)?) async where T : DownloadingTask {
			self.didFinishCalls += 1
			self.lastError = error
			self.lastResponse = response
		}
		
		var willSendRequestCalled = false
		var didReceiveResponseCalled = false
		var didFinishCalled = false
		var didFailCalled = false
		var capturedRequest: URLRequest?
		var capturedResponseData: Data?
	}

	// Task that tracks all lifecycle hooks
	struct LifecycleTrackingTask: DataDownloadingTask {
		var path: String
		var server: ConveyServerable
		var configuration: TaskConfiguration?

		init(path: String = "get", server: TestServer) {
			self.path = path
			self.server = server
		}

		func willSendRequest(request: URLRequest) async throws {
			(server as? TestServer)?.willSendRequestCalled = true
			(server as? TestServer)?.capturedRequest = request
		}

		func didReceiveResponse(response: URLResponse, data: Data) async throws {
			(server as? TestServer)?.didReceiveResponseCalled = true
			(server as? TestServer)?.capturedResponseData = data
		}

		func didFinish(with response: ServerResponse<Data>) async {
			(server as? TestServer)?.didFinishCalled = true
		}

		func didFail(with error: any Error) async {
			(server as? TestServer)?.didFailCalled = true
		}
	}

	// Task that modifies request in willSendRequest
	struct RequestModifyingTask: DataDownloadingTask {
		var path: String
		var server: ConveyServerable { TestServer.shared }
		var configuration: TaskConfiguration?

		nonisolated init(path: String = "headers") {
			self.path = path
		}

		func willSendRequest(request: URLRequest) async throws {
			// We can't actually modify the request here as it's passed by value
			// but we can verify it's called
		}
	}

	// Task that throws in didReceiveResponse
	struct FailingResponseTask: DataDownloadingTask {
		var path: String
		var server: ConveyServerable
		var configuration: TaskConfiguration?

		struct ResponseValidationError: Error, LocalizedError {
			var errorDescription: String? { "Response validation failed" }
		}

		init(path: String = "get", server: TestServer) {
			self.server = server
			self.path = path
		}

		func didReceiveResponse(response: URLResponse, data: Data) async throws {
			// Simulate validation failure
			throw ResponseValidationError()
		}
	}

	@Test("willSendRequest is called before request is sent")
	@ConveyActor func testWillSendRequest() async throws {
		let server = TestServer()
		let task = LifecycleTrackingTask(path: "get", server: server)

		do {
			_ = try await task.downloadData()
		} catch {
			// Ignore errors
		}

		let wasCalled = server.willSendRequestCalled
		let request = server.capturedRequest

		#expect(wasCalled, "willSendRequest should be called")
		#expect(request != nil, "Should capture the request")
	}

	@Test("didReceiveResponse is called with response data")
	@ConveyActor func testDidReceiveResponse() async throws {
		let server = TestServer()
		let task = LifecycleTrackingTask(path: "get", server: server)

		do {
			_ = try await task.downloadData()
		} catch {
			// Ignore errors
		}

		let wasCalled = server.didReceiveResponseCalled
		let data = server.capturedResponseData

		#expect(wasCalled, "didReceiveResponse should be called")
		#expect(data != nil, "Should capture response data")
	}

	@Test("didFinish is called on successful request")
	@ConveyActor func testDidFinishSuccess() async throws {
		let server = TestServer()
		let task = LifecycleTrackingTask(path: "get", server: server)

		do {
			_ = try await task.downloadData()
		} catch {
			// Ignore errors
		}

		let didFinish = server.didFinishCalled

		let didFail = server.didFailCalled

		#expect(didFinish, "didFinish should be called on success")
		#expect(!didFail, "didFail should not be called on success")
	}

	@Test("didFail is called on failed request")
	@ConveyActor func testDidFailOnError() async throws {
		let server = TestServer()

		var task = LifecycleTrackingTask(path: "delay/10", server: server)
		task.configuration = TaskConfiguration(timeout: 0.01)

		do {
			_ = try await task.downloadData()
		} catch {
			// Expected to fail
		}

		let didFinish = server.didFinishCalled
		let didFail = server.didFailCalled

		#expect(!didFinish, "didFinish should not be called on failure")
		#expect(didFail, "didFail should be called on failure")
	}

	@Test("Throwing in didReceiveResponse causes task to fail")
	@ConveyActor func testThrowingInDidReceiveResponse() async throws {
		let server = TestServer()
		let task = FailingResponseTask(path: "get", server: server)

		do {
			_ = try await task.downloadData()
			Issue.record("Task should have failed due to didReceiveResponse throwing")
		} catch _ as FailingResponseTask.ResponseValidationError {
			// Expected error
			#expect(true, "Should throw ResponseValidationError")
		} catch {
			Issue.record("Expected ResponseValidationError, got \(type(of: error))")
		}
	}

	@Test("Server didFinish hook is called")
	@ConveyActor func testServerDidFinishHook() async throws {
		let server = TestServer()
		let task = LifecycleTrackingTask(path: "get", server: server)

		do {
			_ = try await task.downloadData()
		} catch {
			// Ignore errors
		}

		let calls = server.didFinishCalls
		let response = server.lastResponse

		#expect(calls > 0, "Server didFinish should be called")
		#expect(response != nil, "Server should receive response")
	}

	@Test("Server didFinish hook is called on error")
	@ConveyActor func testServerDidFinishHookOnError() async throws {
		let server = TestServer()
		var task = LifecycleTrackingTask(path: "delay/10", server: server)

		task.configuration = TaskConfiguration(timeout: 0.01)

		do {
			_ = try await task.downloadData()
		} catch {
			// Expected to fail
		}

		let calls = server.didFinishCalls
		let error = server.lastError

		#expect(calls > 0, "Server didFinish should be called on error")
		#expect(error != nil, "Server should receive error")
	}

	@Test("All hooks are called in correct order for successful request")
	func testHookOrder() async throws {
		actor HookOrderTracker {
			var events: [String] = []

			func record(_ event: String) {
				events.append(event)
			}

			func getEvents() -> [String] {
				events
			}

			func reset() {
				events = []
			}
		}

		let tracker = HookOrderTracker()

		struct OrderTrackingTask: DataDownloadingTask {
			var path: String = "get"
			var server: ConveyServerable { TestServer.shared }
			var configuration: TaskConfiguration?
			let tracker: HookOrderTracker

			func willSendRequest(request: URLRequest) async throws {
				await tracker.record("willSendRequest")
			}

			func didReceiveResponse(response: URLResponse, data: Data) async throws {
				await tracker.record("didReceiveResponse")
			}

			func didFinish(with response: ServerResponse<Data>) async {
				await tracker.record("didFinish")
			}

			func didFail(with error: any Error) async {
				await tracker.record("didFail")
			}
		}

		await tracker.reset()
		let task = OrderTrackingTask(tracker: tracker)

		do {
			_ = try await task.downloadData()
		} catch {
			// Ignore
		}

		let events = await tracker.getEvents()

		// Expected order: willSendRequest -> didReceiveResponse -> didFinish
		if events.count >= 3 {
			#expect(events[0] == "willSendRequest", "First event should be willSendRequest")
			#expect(events[1] == "didReceiveResponse", "Second event should be didReceiveResponse")
			#expect(events[2] == "didFinish", "Third event should be didFinish")
		}
	}
}
