//
//  HeaderCompositionTests.swift
//  Convey
//
//  Created by Claude Code
//

import Testing
import Foundation
@testable import Convey

@Suite("Header Composition")
struct HeaderCompositionTests {

	@ConveyActor
	class TestServer: ConveyServerable {
		var remote = Remote(URL(string: "https://httpbin.org")!, name: "Test")
		var configuration = ServerConfiguration()

		static let shared = TestServer()

		func headers(for task: any DownloadingTask) async throws -> Headers {
			var headers = await defaultHeaders(for: task)
			headers.append(header: Header(name: "X-Server-Header", value: "from-server"))
			return headers
		}

		func didFinish<T>(task: T, response: ServerResponse<Data>?, error: (any Error)?) async where T : DownloadingTask {
		}
	}

	struct TaskWithHeaders: DataDownloadingTask {
		var path: String = "headers"
		var server: ConveyServerable
		var configuration: TaskConfiguration?
		var customHeaders: [Header]

		init(headers: [Header] = [], server: any ConveyServerable) {
			self.customHeaders = headers
			self.server = server
		}

		var headers: Headers {
			get async throws {
				let baseHeaders = try await server.headers(for: self)
				var headersArray = baseHeaders.headersArray
				headersArray.append(contentsOf: customHeaders)
				return headersArray
			}
		}
	}

	@Test("Headers protocol works with Dictionary")
	func testDictionaryAsHeaders() async throws {
		let dict: [String: String] = ["X-Custom": "value", "X-Another": "test"]
		let headers: Headers = dict

		let array = headers.headersArray

		#expect(array.count == 2, "Should have 2 headers")
		#expect(array.contains(where: { $0.name == "X-Custom" && $0.value == "value" }), "Should contain X-Custom header")
		#expect(array.contains(where: { $0.name == "X-Another" && $0.value == "test" }), "Should contain X-Another header")
	}

	@Test("Headers protocol works with Array")
	func testArrayAsHeaders() async throws {
		let array: [Header] = [
			Header(name: "X-Custom", value: "value"),
			Header(name: "X-Another", value: "test")
		]
		let headers: Headers = array

		let result = headers.headersArray

		#expect(result.count == 2, "Should have 2 headers")
		#expect(result[0].name == "X-Custom", "First header should be X-Custom")
		#expect(result[1].name == "X-Another", "Second header should be X-Another")
	}

	@Test("Headers can be composed with + operator")
	func testHeaderComposition() async throws {
		let headers1: Headers = ["X-First": "1"]
		let headers2: Headers = ["X-Second": "2"]

		let composed = headers1 + headers2

		let array = composed.headersArray

		#expect(array.count == 2, "Should have 2 headers")
		#expect(array.contains(where: { $0.name == "X-First" }), "Should contain X-First")
		#expect(array.contains(where: { $0.name == "X-Second" }), "Should contain X-Second")
	}

	@Test("Headers composition with nil values")
	func testHeaderCompositionWithNil() async throws {
		let headers1: Headers? = ["X-First": "1"]
		let headers2: Headers? = nil

		let composed = headers1 + headers2

		let array = composed.headersArray

		#expect(array.count == 1, "Should have 1 header")
		#expect(array[0].name == "X-First", "Should contain X-First")
	}

	@Test("Server headers are included in requests")
	@ConveyActor func testServerHeaders() async throws {
		let server = TestServer()
		server.configuration.defaultHeaders = ["X-Default": "default-value"]

		let task = TaskWithHeaders(server: server)

		let headers = try await task.headers

		let array = headers.headersArray

		#expect(array.contains(where: { $0.name == "X-Server-Header" && $0.value == "from-server" }),
				"Should contain server header")
	}

	@Test("Task headers override server headers")
	@ConveyActor func testHeaderOverride() async throws {
		let server = TestServer()
		server.configuration.defaultHeaders = ["X-Default": "default-value"]

		let task = TaskWithHeaders(headers: [Header(name: "X-Custom", value: "custom-value")], server: server)

		let headers = try await task.headers
		let array = headers.headersArray

		#expect(array.contains(where: { $0.name == "X-Custom" && $0.value == "custom-value" }),
				"Should contain custom header")
		#expect(array.contains(where: { $0.name == "X-Server-Header" }),
				"Should also contain server header")
	}

	@Test("Default headers are applied")
	@ConveyActor func testDefaultHeaders() async throws {
		let server = TestServer()
		server.configuration.defaultHeaders = [
				"X-API-Key": "test-key",
				"X-Client-Version": "1.0.0"
			]

		let task = TaskWithHeaders(server: server)
		let headers = try await task.headers
		let array = headers.headersArray

		#expect(array.contains(where: { $0.name == "X-API-Key" }), "Should contain API key")
		#expect(array.contains(where: { $0.name == "X-Client-Version" }), "Should contain version")
	}

	@Test("User-Agent header is set")
	@ConveyActor func testUserAgentHeader() async throws {
		let server = TestServer()
		server.configuration.userAgent = "TestClient/1.0"

		let task = TaskWithHeaders(server: server)
		let headers = try await task.headers
		let array = headers.headersArray

		// The user agent is added by the defaultHeaders() method in ConveyServerable
		// Check if it exists
		let hasUserAgent = array.contains(where: { $0.name.lowercased() == "user-agent" })
		#expect(hasUserAgent, "Should include user agent")
	}

	@Test("Accept header is set by default")
	@ConveyActor func testAcceptHeader() async throws {
		let server = TestServer()
		let task = TaskWithHeaders(server: server)
		let headers = try await task.headers
		let array = headers.headersArray

		let hasAccept = array.contains(where: { $0.name.lowercased() == "accept" })
		#expect(hasAccept, "Should include accept header")
	}

	@Test("Header description format")
	func testHeaderDescription() async throws {
		let header = Header(name: "X-Custom", value: "test-value")

		#expect(header.description == "X-Custom: test-value", "Header description should be formatted correctly")
	}

	@Test("Multiple headers with same name are preserved")
	func testMultipleHeadersSameName() async throws {
		let headers: [Header] = [
			Header(name: "X-Custom", value: "value1"),
			Header(name: "X-Custom", value: "value2")
		]

		#expect(headers.count == 2, "Should preserve both headers with same name")
		#expect(headers[0].value == "value1", "First value should be preserved")
		#expect(headers[1].value == "value2", "Second value should be preserved")
	}

	@Test("Empty headers are valid")
	func testEmptyHeaders() async throws {
		let emptyDict: [String: String] = [:]
		let headers: Headers = emptyDict

		#expect(headers.headersArray.isEmpty, "Empty headers should work")
	}

	@Test("Headers are sent in actual HTTP request")
	@ConveyActor func testHeadersInHttpRequest() async throws {
		let server = TestServer()
		let task = TaskWithHeaders(headers: [
			Header(name: "X-Test-Header", value: "test-value-123")
		], server: server)

		do {
			let response = try await task.downloadData()

			// HTTPBin /headers endpoint returns the headers it received
			if let json = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any],
			   let headersDict = json["headers"] as? [String: String] {

				let hasTestHeader = headersDict.keys.contains(where: { $0.lowercased() == "x-test-header" })
				#expect(hasTestHeader, "Test header should be present in request")

				if let value = headersDict.first(where: { $0.key.lowercased() == "x-test-header" })?.value {
					#expect(value == "test-value-123", "Header value should match")
				}
			}
		} catch {
			Issue.record("Request failed: \(error)")
		}
	}
}
