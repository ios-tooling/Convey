//
//  ConveyTests.swift
//  Convey
//
//  Updated to use Swift Testing framework
//

import Testing
import Foundation
@testable import Convey

@Suite("Basic Convey Operations")
struct ConveyBasicTests {

	@Test("GET request downloads data")
	func testGET() async throws {
		let task = SimpleGETTask(url: URL(string: "https://httpbin.org/get")!)
		let response = try await task.downloadData()

		#expect(!response.data.isEmpty, "Should download data")
		#expect(response.statusCode == 200, "Should return 200 OK")
	}

	@Test("Simple GET task with URL")
	func testSimpleGETCreation() async throws {
		let url = URL(string: "https://httpbin.org/get")!
		let task = SimpleGETTask(url: url)

		let taskURL = await Task { @ConveyActor in
			task.url
		}.value

		#expect(taskURL == url, "URL should be set correctly")
	}

	@Test("Task response contains metadata")
	func testResponseMetadata() async throws {
		let task = SimpleGETTask(url: URL(string: "https://httpbin.org/get")!)
		let response = try await task.downloadData()

		#expect(response.duration >= 0, "Duration should be non-negative")
		#expect(response.attemptNumber >= 1, "Should have at least 1 attempt")
		#expect(response.startedAt <= Date(), "Start time should be in the past")
	}

	@Test("Response type is categorized correctly")
	func testResponseType() async throws {
		let task = SimpleGETTask(url: URL(string: "https://httpbin.org/get")!)
		let response = try await task.downloadData()

		#expect(response.responseType == .success, "200 status should be success type")
	}
}

struct SimpleResponse: Codable {
	let success: String
}
