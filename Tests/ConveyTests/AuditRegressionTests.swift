import Foundation
import SwiftData
import Testing
@testable import Convey

private final class AuditURLProtocol: URLProtocol, @unchecked Sendable {
	override class func canInit(with request: URLRequest) -> Bool { true }
	override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
	override func stopLoading() { }

	override func startLoading() {
		guard let url = request.url, let client else { return }
		let data: Data
		switch url.path {
		case "/invalid-json":
			data = Data("{".utf8)
		case "/echo-header":
			data = Data((request.value(forHTTPHeaderField: "X-Prepared") ?? "missing").utf8)
		default:
			data = Data("ok".utf8)
		}
		let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
		client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
		client.urlProtocol(self, didLoad: data)
		client.urlProtocolDidFinishLoading(self)
	}
}

@Suite("Audit regressions")
struct AuditRegressionTests {
	private struct SecretError: LocalizedError {
		var errorDescription: String? { "token=secret" }
	}

	@ConveyActor
	final class StubServer: ConveyServerable {
		var remote = Remote(URL(string: "https://audit.example")!, name: "Audit")
		var configuration = ServerConfiguration()
		var completionCount = 0
		var lastError: (any Error)?
		var lastResponse: ServerResponse<Data>?
		var taskFailureCount = 0

		init() {
			let configuration = URLSessionConfiguration.ephemeral
			configuration.protocolClasses = [AuditURLProtocol.self]
			self.configuration.urlSessionConfiguration = configuration
		}

		func didFinish<T>(task: T, response: ServerResponse<Data>?, error: (any Error)?) where T: DownloadingTask {
			completionCount += 1
			lastResponse = response
			lastError = error
		}
	}

	struct DataTask: DataDownloadingTask {
		var path: String
		var server: ConveyServerable
		var configuration: TaskConfiguration?
		var taskHeaders: Headers = []
		var headers: Headers { get async throws { taskHeaders } }
	}

	struct PreparedTask: DataDownloadingTask {
		var path = "echo-header"
		var server: ConveyServerable
		var configuration: TaskConfiguration?

		func willSendRequest(_ request: URLRequest) async throws -> URLRequest {
			var request = request
			request.setValue("prepared", forHTTPHeaderField: "X-Prepared")
			return request
		}
	}

	struct Payload: Decodable, Sendable {
		let value: String
	}

	struct DecodingTask: DownloadingTask {
		typealias DownloadPayload = Payload
		var path = "invalid-json"
		var server: ConveyServerable
		var configuration: TaskConfiguration?

		func didFail(with error: any Error) {
			(server as? StubServer)?.taskFailureCount += 1
		}
	}

	@Test("Count retention preserves exactly the requested number")
	@ConveyActor
	func countRetention() throws {
		let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
		let container = try ModelContainer(for: RecordedTask.self, configurations: configuration)
		let context = ModelContext(container)
		let server = StubServer()

		for index in 0..<3 {
			var info = TaskRecordingInfo(DataTask(path: "item-\(index)", server: server))
			info.uniqueID = "item-\(index)"
			info.startedAt = Date(timeIntervalSinceReferenceDate: TimeInterval(index))
			context.insert(RecordedTask(info: info, launchedAt: .now))
		}
		try context.save()

		context.removeTasks(greaterThan: 2)
		#expect(try context.fetchCount(FetchDescriptor<RecordedTask>()) == 2)

		context.removeTasks(greaterThan: 0)
		#expect(try context.fetchCount(FetchDescriptor<RecordedTask>()) == 0)
	}

	@Test("Unknown configured HTTP statuses still produce an HTTP error")
	func unknownHTTPStatuses() throws {
		let error = try #require(HTTPError.withStatusCode(599, data: nil, throwingStatusCategories: [500], underlyingError: nil))
		#expect(error.statusCode == 599)
	}

	@Test("Typed decode failures run failure hooks instead of success hooks")
	@ConveyActor
	func decodeFailureLifecycle() async {
		let server = StubServer()
		let task = DecodingTask(server: server)

		await #expect(throws: (any Error).self) {
			_ = try await task.download()
		}

		#expect(server.taskFailureCount == 1)
		#expect(server.completionCount == 1)
		#expect(server.lastError != nil)
		#expect(server.lastResponse == nil)
	}

	@Test("Prepared requests are the requests transmitted")
	@ConveyActor
	func requestPreparation() async throws {
		let response = try await PreparedTask(server: StubServer()).downloadData()
		#expect(String(data: response.data, encoding: .utf8) == "prepared")
	}

	@Test("Task headers override server headers case-insensitively")
	@ConveyActor
	func headerPrecedence() async throws {
		let server = StubServer()
		server.configuration.defaultHeaders = ["Authorization": "server"]
		let task = DataTask(
			path: "ok",
			server: server,
			taskHeaders: [Header(name: "authorization", value: "task")]
		)

		let request = try await task.request
		#expect(request.value(forHTTPHeaderField: "Authorization") == "task")
	}

	@Test("Matching requests own independent URL sessions")
	@ConveyActor
	func requestSessionOwnership() async throws {
		let server = StubServer()
		let first = try await ConveySession(server: server, task: DataTask(path: "one", server: server))
		let second = try await ConveySession(server: server, task: DataTask(path: "two", server: server))

		#expect(first.session !== second.session)
	}

	@Test("Recorded metadata omits bodies and query values by default")
	@ConveyActor
	func recordingPrivacyDefaults() throws {
		let server = StubServer()
		var info = TaskRecordingInfo(DataTask(path: "ok", server: server))
		var request = URLRequest(url: URL(string: "https://audit.example/items?token=secret")!)
		request.httpBody = Data("password=secret".utf8)

		info.record(url: request.url)
		info.urlRequest = request
		info.record(responseData: Data("private response".utf8))
		info.record(error: SecretError())

		#expect(info.url?.query == nil)
		#expect(info.request?.url?.query == nil)
		#expect(info.httpBody == nil)
		#expect(info.data == nil)
		#expect(info.error?.contains("secret") == false)
	}

	@Test("Image max-size matching rejects oversized dimensions")
	func imageSizeMatching() {
		let maxSize = ImageSize.less(than: CGSize(width: 100, height: 80), tolerance: 0)
		#expect(maxSize.matches(size: CGSize(width: 100, height: 80)))
		#expect(maxSize.matches(size: CGSize(width: 50, height: 40)))
		#expect(!maxSize.matches(size: CGSize(width: 101, height: 80)))
		#expect(!maxSize.matches(size: CGSize(width: 100, height: 81)))
	}

	@Test("Image fit and fill geometry handles both orientations")
	func imageScalingGeometry() {
		let landscape = CGSize(width: 200, height: 100)
		let portrait = CGSize(width: 100, height: 200)
		let square = CGSize(width: 100, height: 100)

		#expect(landscape.scaled(within: square, toFit: true) == CGSize(width: 100, height: 50))
		#expect(portrait.scaled(within: square, toFit: true) == CGSize(width: 50, height: 100))
		#expect(landscape.scaled(within: square, toFit: false) == square)
		#expect(portrait.scaled(within: square, toFit: false) == square)
	}
}
