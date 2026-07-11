//
//  HeaderRedactionTests.swift
//  Convey
//

import Testing
import Foundation
@testable import Convey

@Suite("Header Redaction")
struct HeaderRedactionTests {
	@ConveyActor
	class TestServer: ConveyServerable {
		var remote = Remote(URL(string: "https://api.example.com")!, name: "RedactionTest")
		var configuration = ServerConfiguration()

		func didFinish<T>(task: T, response: ServerResponse<Data>?, error: (any Error)?) async where T: DownloadingTask { }
	}

	struct KeyedTask: DataDownloadingTask {
		var path = "v1/messages"
		var server: ConveyServerable
		var configuration: TaskConfiguration?
		var redactedHeaders: Set<String> { ["X-Custom-Secret"] }

		var headers: Headers {
			get async throws {
				["Authorization": "Bearer sk-super-secret", "X-Custom-Secret": "hunter2", "Content-Type": "application/json"]
			}
		}
	}

	@Test("CodableURLRequest redacts case-insensitively and preserves other headers")
	func codableRequestRedaction() {
		var request = URLRequest(url: URL(string: "https://api.example.com")!)
		request.setValue("Bearer sk-123", forHTTPHeaderField: "authorization")
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")

		var codable = CodableURLRequest(request)
		codable.redact(headersNamed: ["Authorization"])

		let headers = codable.allHTTPHeaderFields ?? [:]
		#expect(headers.values.contains(Constants.redactedValue))
		#expect(!headers.values.contains("Bearer sk-123"))
		#expect(headers["Content-Type"] == "application/json")
	}

	@Test("CodableURLResponse redacts response headers")
	func codableResponseRedaction() throws {
		let url = URL(string: "https://api.example.com")!
		let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Set-Cookie": "session=abc123", "Content-Type": "text/plain"]))

		var codable = CodableURLResponse(response)
		codable.redact(headersNamed: ["set-cookie"])

		#expect(codable.allHeaderFields?["Set-Cookie"] == Constants.redactedValue)
		#expect(codable.allHeaderFields?["Content-Type"] == "text/plain")
	}

	@Test("Server configuration redacts common credential headers by default")
	func defaultRedactionList() {
		let defaults = ServerConfiguration().redactedHeaders.map { $0.lowercased() }
		#expect(defaults.contains("authorization"))
		#expect(defaults.contains("x-api-key"))
		#expect(defaults.contains("cookie"))
	}

	@ConveyActor @Test("Task recording captures redacted headers only")
	func recordingRedaction() async throws {
		let task = KeyedTask(server: TestServer())
		var info = TaskRecordingInfo(task)

		info.urlRequest = try await task.request

		let recorded = try #require(info.request?.allHTTPHeaderFields)
		#expect(!recorded.values.contains("Bearer sk-super-secret"))
		#expect(!recorded.values.contains("hunter2"))
		#expect(recorded["Content-Type"] == "application/json")

		let described = info.request?.description ?? ""
		#expect(!described.contains("sk-super-secret"))
		#expect(!described.contains("hunter2"))
	}

	@ConveyActor @Test("Redaction names merge from server, task configuration, and task")
	func redactionSources() {
		var task = KeyedTask(server: TestServer())
		task.configuration = TaskConfiguration(redactedHeaders: ["X-Config-Secret"])

		let names = task.allRedactedHeaderNames
		#expect(names.contains("Authorization"))
		#expect(names.contains("X-Custom-Secret"))
		#expect(names.contains("X-Config-Secret"))
	}

	@ConveyActor @Test("redactedHeaders builder sets task configuration")
	func builder() {
		let task = KeyedTask(server: TestServer()).redactedHeaders(["X-Built"])
		#expect(task.configuration?.redactedHeaders == ["X-Built"])
	}

	@Test("TaskConfiguration merge unions redaction lists")
	func configurationMerge() {
		let base = TaskConfiguration(redactedHeaders: ["A"])
		let merged = base.merged(with: TaskConfiguration(redactedHeaders: ["B"]))
		#expect(merged.redactedHeaders == ["A", "B"])
	}

	@Test("TaskConfiguration redaction list survives a Codable round trip")
	func configurationCoding() throws {
		let config = TaskConfiguration(redactedHeaders: ["Authorization", "X-API-Key"])
		let decoded = try JSONDecoder().decode(TaskConfiguration.self, from: JSONEncoder().encode(config))
		#expect(decoded.redactedHeaders == ["Authorization", "X-API-Key"])
	}
}
