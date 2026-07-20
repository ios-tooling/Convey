import Foundation
import Testing
@testable import Convey

@Suite("Network Interface HTTP Client")
struct NetworkInterfaceHTTPClientTests {
	@Test("Configuration stores a required interface")
	func configurationStoresARequiredInterface() {
		var configuration = ServerConfiguration()
		configuration.requiredNetworkInterface = .cellular
		#expect(configuration.requiredNetworkInterface == .cellular)
	}

	@Test("Serializes an HTTP request")
	func serializesAnHTTPRequest() throws {
		var request = URLRequest(url: URL(string: "https://example.com/reports?page=2")!)
		request.httpMethod = "POST"
		request.httpBody = Data("{}".utf8)
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		let text = try #require(String(data: HTTPRequestSerializer.data(for: request), encoding: .utf8))
		#expect(text.hasPrefix("POST /reports?page=2 HTTP/1.1\r\n"))
		#expect(text.contains("Host: example.com\r\n"))
		#expect(text.contains("Content-Length: 2\r\n"))
		#expect(text.hasSuffix("\r\n\r\n{}"))
	}

	@Test("Parses content-length and chunked HTTP responses")
	func parsesContentLengthAndChunkedHTTPResponses() throws {
		let url = URL(string: "https://example.com/reports")!
		let contentLength = Data("HTTP/1.1 200 OK\r\nContent-Length: 5\r\nContent-Type: text/plain\r\n\r\nhello".utf8)
		let (lengthData, lengthResponse) = try HTTPResponseParser.parse(contentLength, requestURL: url)
		#expect(String(data: lengthData, encoding: .utf8) == "hello")
		#expect((lengthResponse as? HTTPURLResponse)?.statusCode == 200)

		let chunked = Data("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n6\r\n world\r\n0\r\n\r\n".utf8)
		let (chunkedData, _) = try HTTPResponseParser.parse(chunked, requestURL: url)
		#expect(String(data: chunkedData, encoding: .utf8) == "hello world")
	}
}
