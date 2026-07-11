//
//  StreamingTests.swift
//  Convey
//

import Testing
import Foundation
@testable import Convey

final class SSEStubProtocol: URLProtocol {
	override class func canInit(with request: URLRequest) -> Bool { true }
	override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
	override func stopLoading() { }

	override func startLoading() {
		guard let url = request.url, let client else { return }

		if url.path.hasSuffix("fail") {
			let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: "HTTP/1.1", headerFields: nil)!
			client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
			client.urlProtocol(self, didLoad: Data("upstream exploded".utf8))
		} else {
			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "text/event-stream"])!
			client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
			client.urlProtocol(self, didLoad: Data("event: delta\ndata: chunk one\n\n".utf8))
			client.urlProtocol(self, didLoad: Data("data: chunk two\n\ndata: [DONE]\n\n".utf8))
		}
		client.urlProtocolDidFinishLoading(self)
	}
}

@Suite("SSE Streaming")
struct StreamingTests {
	@ConveyActor
	class StubbedServer: ConveyServerable {
		var remote = Remote(URL(string: "https://stub.example.com")!, name: "StreamingTest")
		var configuration = ServerConfiguration()

		init() {
			configuration.urlSessionConfiguration = {
				let config = URLSessionConfiguration.ephemeral
				config.protocolClasses = [SSEStubProtocol.self]
				return config
			}()
		}

		func didFinish<T>(task: T, response: ServerResponse<Data>?, error: (any Error)?) async where T: DownloadingTask { }
	}

	struct StreamTask: DataDownloadingTask {
		var path: String
		var server: ConveyServerable
		var configuration: TaskConfiguration? = TaskConfiguration(echoStyle: [])
		var acceptType: String { "text/event-stream" }
	}

	@ConveyActor @Test("Streaming yields parsed events in order")
	func streamEvents() async throws {
		let task = StreamTask(path: "events", server: StubbedServer())
		let stream = try await task.stream()

		#expect(stream.statusCode == 200)

		var events: [ServerSentEvent] = []
		for try await event in stream {
			events.append(event)
		}

		#expect(events.count == 3)
		#expect(events[0].event == "delta")
		#expect(events[0].data == "chunk one")
		#expect(events[1].data == "chunk two")
		#expect(events[2].data == "[DONE]")
	}

	@ConveyActor @Test("Error status throws instead of streaming")
	func errorStatus() async throws {
		let task = StreamTask(path: "fail", server: StubbedServer())

		await #expect(throws: (any Error).self) {
			_ = try await task.stream()
		}
	}
}
