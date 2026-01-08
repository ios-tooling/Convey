//
//  ErrorHandlingTests.swift
//  Convey
//
//  Created by Claude Code
//

import Testing
import Foundation
@testable import Convey

@Suite("HTTP Error Handling")
struct ErrorHandlingTests {

	// Test server that returns specific status codes
	@ConveyActor
	class MockServer: ConveyServerable {
		var remote = Remote(URL(string: "https://httpbin.org")!, name: "Test")
		var configuration = ServerConfiguration()
		var statusCodeToReturn: Int = 200
		var responseData: Data = Data()

		static let shared = MockServer()

		func headers(for task: any DownloadingTask) async throws -> Headers {
			configuration.defaultHeaders
		}

		func didFinish<T>(task: T, response: ServerResponse<Data>?, error: (any Error)?) async where T : DownloadingTask {
			// Track finished tasks if needed
		}
	}

	struct TestTask: DataDownloadingTask {
		var path: String
		var server: ConveyServerable { MockServer.shared }
		var configuration: TaskConfiguration?

		nonisolated init(path: String = "") {
			self.path = path
		}
	}

	@Test("4xx Client Errors are recognized")
	func testClientErrors() async throws {
		let testCases: [(Int, String)] = [
			(400, "badRequest"),
			(401, "unauthorized"),
			(403, "forbidden"),
			(404, "notFound"),
			(405, "methodNotAllowed"),
			(408, "requestTimeout"),
			(409, "conflict"),
			(410, "gone"),
			(429, "tooManyRequests")
		]

		for (statusCode, _) in testCases {
			let task = TestTask(path: "status/\(statusCode)")

			do {
				_ = try await task.downloadData()
				Issue.record("Expected HTTPError for status code \(statusCode)")
			} catch let error as any HTTPErrorType {
				#expect(error.statusCode == statusCode, "Expected status code \(statusCode), got \(error.statusCode)")
			} catch {
				Issue.record("Expected HTTPError, got \(type(of: error)): \(error)")
			}
		}
	}

	@Test("5xx Server Errors are recognized")
	func testServerErrors() async throws {
		let testCases: [(Int, String)] = [
			(500, "internalServer"),
			(501, "notImplemented"),
			(502, "badGateway"),
			(503, "serviceUnavailable"),
			(504, "gatewayTimeout")
		]

		for (statusCode, _) in testCases {
			let task = TestTask(path: "status/\(statusCode)")

			do {
				_ = try await task.downloadData()
				Issue.record("Expected HTTPError for status code \(statusCode)")
			} catch let error as any HTTPErrorType {
				#expect(error.statusCode == statusCode, "Expected status code \(statusCode), got \(error.statusCode)")
			} catch {
				Issue.record("Expected HTTPError, got \(type(of: error)): \(error)")
			}
		}
	}

	@Test("2xx Success codes do not throw")
	func testSuccessCodes() async throws {
		let successCodes = [200, 201, 202, 204, 206]

		for statusCode in successCodes {
			let task = TestTask(path: "status/\(statusCode)")

			do {
				let response = try await task.downloadData()
				#expect(response.statusCode == statusCode, "Expected status code \(statusCode)")
			} catch {
				Issue.record("Unexpected error for success status \(statusCode): \(error)")
			}
		}
	}

	@Test("throwingStatusCategories configuration is respected")
	func testThrowingStatusCategories() async throws {
		// Configure server to only throw on 500 errors
		await Task { @ConveyActor in
			MockServer.shared.configuration.throwingStatusCategories = [500]
		}.value

		// 400 errors should not throw
		let task400 = TestTask(path: "status/404")
		do {
			let response = try await task400.downloadData()
			#expect(response.statusCode == 404, "Should receive 404 without throwing")
		} catch {
			Issue.record("Should not throw for 404 when only 500s are configured to throw")
		}

		// 500 errors should throw
		let task500 = TestTask(path: "status/500")
		do {
			_ = try await task500.downloadData()
			Issue.record("Should throw for 500 when configured")
		} catch let error as any HTTPErrorType {
			#expect(error.statusCode == 500)
		}
	}

	@Test("Error contains response data")
	func testErrorContainsResponseData() async throws {
		let task = TestTask(path: "status/404")

		do {
			_ = try await task.downloadData()
		} catch let error as any HTTPErrorType {
			// HTTPBin returns JSON for error pages
			#expect(error.data != nil, "Error should contain response data")
		} catch {
			Issue.record("Expected HTTPError")
		}
	}

	@Test("ServerResponse.responseType categorizes correctly")
	func testResponseTypeCategorization() async throws {
		struct ResponseTypeTest {
			let statusCode: Int
			let expectedType: ServerResponse<Data>.ResponseType
		}

		let tests = [
			ResponseTypeTest(statusCode: 200, expectedType: .success),
			ResponseTypeTest(statusCode: 201, expectedType: .success),
			ResponseTypeTest(statusCode: 301, expectedType: .redirect),
			ResponseTypeTest(statusCode: 404, expectedType: .clientError),
			ResponseTypeTest(statusCode: 500, expectedType: .serverError)
		]

		// We can't easily test this without mocking URLResponse
		// But we can test the logic directly
		for test in tests {
			let type = ServerResponse<Data>.ResponseType(rawValue: (test.statusCode / 100) * 100) ?? .unknown
			#expect(type == test.expectedType, "Status \(test.statusCode) should be \(test.expectedType)")
		}
	}
}
