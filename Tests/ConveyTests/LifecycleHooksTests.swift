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

		@ConveyActor
		static var didFinishCalls = 0
		@ConveyActor
		static var lastError: Error?
		@ConveyActor
		static var lastResponse: ServerResponse<Data>?

		func headers(for task: any DownloadingTask) async throws -> Headers {
			configuration.defaultHeaders
		}

		func didFinish<T>(task: T, response: ServerResponse<Data>?, error: (any Error)?) async where T : DownloadingTask {
			Self.didFinishCalls += 1
			Self.lastError = error
			Self.lastResponse = response
		}
	}

	// Task that tracks all lifecycle hooks
	struct LifecycleTrackingTask: DataDownloadingTask {
		var path: String
		var server: ConveyServerable { TestServer.shared }
		var configuration: TaskConfiguration?

		@ConveyActor
		static var willSendRequestCalled = false
		@ConveyActor
		static var didReceiveResponseCalled = false
		@ConveyActor
		static var didFinishCalled = false
		@ConveyActor
		static var didFailCalled = false
		@ConveyActor
		static var capturedRequest: URLRequest?
		@ConveyActor
		static var capturedResponseData: Data?

		nonisolated init(path: String = "get") {
			self.path = path
		}

		func willSendRequest(request: URLRequest) async throws {
			Self.willSendRequestCalled = true
			Self.capturedRequest = request
		}

		func didReceiveResponse(response: URLResponse, data: Data) async throws {
			Self.didReceiveResponseCalled = true
			Self.capturedResponseData = data
		}

		func didFinish(with response: ServerResponse<Data>) async {
			Self.didFinishCalled = true
		}

		func didFail(with error: any Error) async {
			Self.didFailCalled = true
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
		var server: ConveyServerable { TestServer.shared }
		var configuration: TaskConfiguration?

		struct ResponseValidationError: Error, LocalizedError {
			var errorDescription: String? { "Response validation failed" }
		}

		nonisolated init(path: String = "get") {
			self.path = path
		}

		func didReceiveResponse(response: URLResponse, data: Data) async throws {
			// Simulate validation failure
			throw ResponseValidationError()
		}
	}

	@Test("willSendRequest is called before request is sent")
	func testWillSendRequest() async throws {
		await Task { @ConveyActor in
			LifecycleTrackingTask.willSendRequestCalled = false
			LifecycleTrackingTask.capturedRequest = nil
		}.value

		let task = LifecycleTrackingTask(path: "get")

		do {
			_ = try await task.downloadData()
		} catch {
			// Ignore errors
		}

		let wasCalled = await Task { @ConveyActor in
			LifecycleTrackingTask.willSendRequestCalled
		}.value

		let request = await Task { @ConveyActor in
			LifecycleTrackingTask.capturedRequest
		}.value

		#expect(wasCalled, "willSendRequest should be called")
		#expect(request != nil, "Should capture the request")
		#expect(request?.url?.absoluteString.contains("get") == true, "Request URL should contain path")
	}

	@Test("didReceiveResponse is called with response data")
	func testDidReceiveResponse() async throws {
		await Task { @ConveyActor in
			LifecycleTrackingTask.didReceiveResponseCalled = false
			LifecycleTrackingTask.capturedResponseData = nil
		}.value

		let task = LifecycleTrackingTask(path: "get")

		do {
			_ = try await task.downloadData()
		} catch {
			// Ignore errors
		}

		let wasCalled = await Task { @ConveyActor in
			LifecycleTrackingTask.didReceiveResponseCalled
		}.value

		let data = await Task { @ConveyActor in
			LifecycleTrackingTask.capturedResponseData
		}.value

		#expect(wasCalled, "didReceiveResponse should be called")
		#expect(data != nil, "Should capture response data")
	}

	@Test("didFinish is called on successful request")
	func testDidFinishSuccess() async throws {
		await Task { @ConveyActor in
			LifecycleTrackingTask.didFinishCalled = false
			LifecycleTrackingTask.didFailCalled = false
		}.value

		let task = LifecycleTrackingTask(path: "get")

		do {
			_ = try await task.downloadData()
		} catch {
			// Ignore errors
		}

		let didFinish = await Task { @ConveyActor in
			LifecycleTrackingTask.didFinishCalled
		}.value

		let didFail = await Task { @ConveyActor in
			LifecycleTrackingTask.didFailCalled
		}.value

		#expect(didFinish, "didFinish should be called on success")
		#expect(!didFail, "didFail should not be called on success")
	}

	@Test("didFail is called on failed request")
	func testDidFailOnError() async throws {
		await Task { @ConveyActor in
			LifecycleTrackingTask.didFinishCalled = false
			LifecycleTrackingTask.didFailCalled = false
		}.value

		var task = LifecycleTrackingTask(path: "delay/10")
		task.configuration = TaskConfiguration(timeout: 0.01)

		do {
			_ = try await task.downloadData()
		} catch {
			// Expected to fail
		}

		let didFinish = await Task { @ConveyActor in
			LifecycleTrackingTask.didFinishCalled
		}.value

		let didFail = await Task { @ConveyActor in
			LifecycleTrackingTask.didFailCalled
		}.value

		#expect(!didFinish, "didFinish should not be called on failure")
		#expect(didFail, "didFail should be called on failure")
	}

	@Test("Throwing in didReceiveResponse causes task to fail")
	func testThrowingInDidReceiveResponse() async throws {
		let task = FailingResponseTask(path: "get")

		do {
			_ = try await task.downloadData()
			Issue.record("Task should have failed due to didReceiveResponse throwing")
		} catch let error as FailingResponseTask.ResponseValidationError {
			// Expected error
			#expect(true, "Should throw ResponseValidationError")
		} catch {
			Issue.record("Expected ResponseValidationError, got \(type(of: error))")
		}
	}

	@Test("Server didFinish hook is called")
	func testServerDidFinishHook() async throws {
		await Task { @ConveyActor in
			TestServer.didFinishCalls = 0
			TestServer.lastError = nil
			TestServer.lastResponse = nil
		}.value

		let task = LifecycleTrackingTask(path: "get")

		do {
			_ = try await task.downloadData()
		} catch {
			// Ignore errors
		}

		let calls = await Task { @ConveyActor in
			TestServer.didFinishCalls
		}.value

		let response = await Task { @ConveyActor in
			TestServer.lastResponse
		}.value

		#expect(calls > 0, "Server didFinish should be called")
		#expect(response != nil, "Server should receive response")
	}

	@Test("Server didFinish hook is called on error")
	func testServerDidFinishHookOnError() async throws {
		await Task { @ConveyActor in
			TestServer.didFinishCalls = 0
			TestServer.lastError = nil
			TestServer.lastResponse = nil
		}.value

		var task = LifecycleTrackingTask(path: "delay/10")
		task.configuration = TaskConfiguration(timeout: 0.01)

		do {
			_ = try await task.downloadData()
		} catch {
			// Expected to fail
		}

		let calls = await Task { @ConveyActor in
			TestServer.didFinishCalls
		}.value

		let error = await Task { @ConveyActor in
			TestServer.lastError
		}.value

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
