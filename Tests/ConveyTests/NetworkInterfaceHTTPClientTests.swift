import Foundation
import XCTest
@testable import Convey

final class NetworkInterfaceHTTPClientTests: XCTestCase {
	func testConfigurationStoresARequiredInterface() {
		var configuration = ServerConfiguration()
		configuration.requiredNetworkInterface = .cellular
		XCTAssertEqual(configuration.requiredNetworkInterface, .cellular)
	}

	func testSerializesAnHTTPRequest() throws {
		var request = URLRequest(url: URL(string: "https://example.com/reports?page=2")!)
		request.httpMethod = "POST"
		request.httpBody = Data("{}".utf8)
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		let text = try XCTUnwrap(String(data: HTTPRequestSerializer.data(for: request), encoding: .utf8))
		XCTAssertTrue(text.hasPrefix("POST /reports?page=2 HTTP/1.1\r\n"))
		XCTAssertTrue(text.contains("Host: example.com\r\n"))
		XCTAssertTrue(text.contains("Content-Length: 2\r\n"))
		XCTAssertTrue(text.hasSuffix("\r\n\r\n{}"))
	}

	func testParsesContentLengthAndChunkedHTTPResponses() throws {
		let url = URL(string: "https://example.com/reports")!
		let contentLength = Data("HTTP/1.1 200 OK\r\nContent-Length: 5\r\nContent-Type: text/plain\r\n\r\nhello".utf8)
		let (lengthData, lengthResponse) = try HTTPResponseParser.parse(contentLength, requestURL: url)
		XCTAssertEqual(String(data: lengthData, encoding: .utf8), "hello")
		XCTAssertEqual((lengthResponse as? HTTPURLResponse)?.statusCode, 200)

		let chunked = Data("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n6\r\n world\r\n0\r\n\r\n".utf8)
		let (chunkedData, _) = try HTTPResponseParser.parse(chunked, requestURL: url)
		XCTAssertEqual(String(data: chunkedData, encoding: .utf8), "hello world")
	}
}
