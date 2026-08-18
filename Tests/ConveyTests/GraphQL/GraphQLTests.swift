import Foundation
import Testing
@testable import Convey

private final class GraphQLStubProtocol: URLProtocol, @unchecked Sendable {
	private static let lock = NSLock()
	private nonisolated(unsafe) static var counts: [String: Int] = [:]

	static func reset(_ host: String) { lock.withLock { counts[host] = 0 } }
	static func count(for host: String) -> Int { lock.withLock { counts[host, default: 0] } }

	override class func canInit(with request: URLRequest) -> Bool { true }
	override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
	override func stopLoading() { }

	override func startLoading() {
		guard let url = request.url, let client else { return }
		let host = url.host ?? "unknown"
		let attempt = Self.lock.withLock { () -> Int in
			Self.counts[host, default: 0] += 1
			return Self.counts[host, default: 0]
		}
		let json: String
		switch host {
		case "partial.example":
			json = #"{"data":{"value":"partial"},"errors":[{"type":"FORBIDDEN","message":"field denied"}]}"#
		case "missing.example":
			json = #"{"data":null}"#
		case "retry.example" where attempt == 1:
			json = #"{"data":null,"errors":[{"type":"RATE_LIMITED","message":"slow down","extensions":{"retryAfter":0}}]}"#
		case "pages.example" where attempt == 1,
			"cancel.example" where attempt == 1,
			"pageerror.example" where attempt == 1:
			json = #"{"data":{"items":{"nodes":[1,2],"pageInfo":{"hasNextPage":true,"hasPreviousPage":false,"endCursor":"c1"}}}}"#
		case "pages.example":
			json = #"{"data":{"items":{"nodes":[3,4],"pageInfo":{"hasNextPage":false,"hasPreviousPage":true,"endCursor":null}}}}"#
		case "cancel.example":
			json = #"{"data":{"items":{"nodes":[3],"pageInfo":{"hasNextPage":false,"hasPreviousPage":true,"endCursor":null}}}}"#
		case "pageerror.example":
			json = #"{"data":null,"errors":[{"type":"FORBIDDEN","message":"second page denied"}]}"#
		case "nilcursor.example":
			json = #"{"data":{"items":{"nodes":[1],"pageInfo":{"hasNextPage":true,"hasPreviousPage":false,"endCursor":null}}}}"#
		default:
			json = #"{"data":{"value":"ok"}}"#
		}
		let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
		client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
		client.urlProtocol(self, didLoad: Data(json.utf8))
		client.urlProtocolDidFinishLoading(self)
	}
}

@ConveyActor
private final class GraphQLTestServer: ConveyServerable {
	var remote: Remote
	var configuration = ServerConfiguration()

	init(host: String) {
		remote = Remote(URL(string: "https://\(host)/graphql")!, name: "GraphQL test")
		let session = URLSessionConfiguration.ephemeral
		session.protocolClasses = [GraphQLStubProtocol.self]
		configuration.urlSessionConfiguration = session
		configuration.defaultHeaders = ["Authorization": "Bearer test"]
	}
}

private struct ValuePayload: Codable, Sendable, Equatable { let value: String }

private struct ValueTask: GraphQLTask {
	typealias GraphQLPayload = ValuePayload
	var configuration: TaskConfiguration?
	var server: ConveyServerable
	var query = "query Value { value }"
	var variables: GraphQLVariables?
	var operationName: String?
	var allowsPartialResults = false
	var redactedVariables: Set<String> = []
}

private struct PagePayload: Decodable, Sendable { let items: GraphQLConnection<Int> }

private struct PageTask: PaginatedGraphQLTask {
	typealias GraphQLPayload = PagePayload
	typealias PageNode = Int
	var configuration: TaskConfiguration?
	var server: ConveyServerable
	var cursor: String?
	var query = "query Items($after: String) { items(after: $after) { nodes pageInfo { hasNextPage endCursor } } }"
	var variables: GraphQLVariables? { cursor.map { ["after": .string($0)] } }
	func withCursor(_ cursor: String?) -> PageTask { var copy = self; copy.cursor = cursor; return copy }
	func connection(from payload: PagePayload) -> GraphQLConnection<Int> { payload.items }
}

@Suite("GraphQL request building")
struct GraphQLRequestTests {
	@Test("Absent variables and operation name do not become JSON null")
	@ConveyActor func omitsAbsentVariablesAndOperationName() async throws {
		let server = GraphQLTestServer(host: "success.example")
		let request = try await ValueTask(server: server).request
		let body = try #require(request.httpBody)
		let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
		#expect(request.httpMethod == "POST")
		#expect(request.url == server.remote.url)
		#expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test")
		#expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
		#expect(object["query"] as? String == "query Value { value }")
		#expect(object["variables"] == nil)
		#expect(object["operationName"] == nil)
	}

	@Test("GraphQL null is distinct from an absent variable")
	@ConveyActor func encodesNullVariableDistinctlyFromAbsent() async throws {
		let server = GraphQLTestServer(host: "success.example")
		let variables: GraphQLVariables = ["clearMe": nil, "first": 50, "states": ["OPEN"]]
		let request = try await ValueTask(server: server, variables: variables).request
		let body = try #require(request.httpBody)
		let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
		let encoded = try #require(object["variables"] as? [String: Any])
		#expect(encoded["clearMe"] is NSNull)
		#expect(encoded["missing"] == nil)
		#expect(encoded["first"] as? Int == 50)
	}

	@Test("A hand-declared Encodable variables struct is preserved")
	func passthroughVariablesRoundTrip() throws {
		struct Typed: Encodable, Sendable { let owner: String; let first: Int }
		let encoded = try JSONEncoder().encode(GraphQLVariables(encoding: Typed(owner: "ios-tooling", first: 50)))
		let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
		#expect(object["owner"] as? String == "ios-tooling")
		#expect(object["first"] as? Int == 50)
	}

	@Test("Request JSON uses stable sorted keys")
	@ConveyActor func stableVariableOrdering() async throws {
		let task = ValueTask(server: GraphQLTestServer(host: "success.example"), variables: ["zeta": 1, "alpha": 2])
		let request = try await task.request
		let body = try #require(request.httpBody)
		let text = try #require(String(data: body, encoding: .utf8))
		let alpha = try #require(text.range(of: "\"alpha\""))
		let zeta = try #require(text.range(of: "\"zeta\""))
		#expect(alpha.lowerBound < zeta.lowerBound)
	}

	@Test("Transitive fragments are deterministic and deduplicated")
	@ConveyActor func appendsTransitiveFragmentsOnce() throws {
		let leaf = GraphQLFragment(name: "Leaf", text: "fragment Leaf on User { login }")
		let first = GraphQLFragment(name: "First", dependencies: [leaf], text: "fragment First on User { ...Leaf }")
		let second = GraphQLFragment(name: "Second", dependencies: [leaf], text: "fragment Second on User { ...Leaf }")
		struct FragmentTask: GraphQLTask {
			typealias GraphQLPayload = ValuePayload
			var configuration: TaskConfiguration?
			var query = "query Q { viewer { ...First ...Second } }"
			var fragments: [GraphQLFragment]
		}
		let document = try FragmentTask(fragments: [second, first]).fullQueryDocument
		#expect(document.components(separatedBy: "fragment Leaf").count == 2)
		let firstRange = try #require(document.range(of: "fragment First"))
		let leafRange = try #require(document.range(of: "fragment Leaf"))
		#expect(firstRange.lowerBound < leafRange.lowerBound)
	}

	@Test("Fragment cycles throw a useful error instead of recursing")
	func detectsFragmentCycle() throws {
		let aLeaf = GraphQLFragment(name: "A", text: "fragment A on User { login }")
		let b = GraphQLFragment(name: "B", dependencies: [aLeaf], text: "fragment B on User { ...A }")
		let a = GraphQLFragment(name: "A", dependencies: [b], text: aLeaf.text)
		#expect(throws: GraphQLFragmentError.self) { try GraphQLFragmentComposer.compose(query: "query Q { viewer { ...A } }", fragments: [a]) }
	}

	@Test("A processed .graphql document loads byte-for-byte")
	func loadsDocumentResource() {
		let document = GraphQLDocument.named("RepositoryName", in: .module)
		#expect(document.contains("query RepositoryName"))
	}

	@Test("Echo output is readable, sorted, and redacted")
	@ConveyActor func readableEcho() {
		let task = ValueTask(server: GraphQLTestServer(host: "success.example"), variables: ["token": "secret", "owner": "ios-tooling"], redactedVariables: ["token"])
		let text = task.echoText(for: nil)
		#expect(text.contains("query Value { value }"))
		#expect(text.contains("<redacted>"))
		#expect(!text.contains("secret"))
	}
}

@Suite("GraphQL response handling", .serialized)
struct GraphQLResponseTests {
	@Test("Successful envelopes unwrap to their data payload")
	@ConveyActor func unwrapsDataOnSuccess() async throws {
		GraphQLStubProtocol.reset("success.example")
		#expect(try await ValueTask(server: GraphQLTestServer(host: "success.example")).execute() == ValuePayload(value: "ok"))
	}

	@Test("Errors with partial data throw by default but can opt in")
	@ConveyActor func partialDataPolicy() async throws {
		let server = GraphQLTestServer(host: "partial.example")
		await #expect(throws: GraphQLTaskError.self) { try await ValueTask(server: server).execute() }
		#expect(try await ValueTask(server: server, allowsPartialResults: true).execute() == ValuePayload(value: "partial"))
	}

	@Test("A data-less, error-less response throws missingData")
	@ConveyActor func missingData() async {
		await #expect(throws: GraphQLTaskError.self) { try await ValueTask(server: GraphQLTestServer(host: "missing.example")).execute() }
	}

	@Test("Captured GitHub errors decode paths and map to typed cases")
	func mapsCapturedGitHubError() throws {
		let url = try #require(Bundle.module.url(forResource: "github-not-found", withExtension: "json"))
		let envelope = try JSONDecoder().decode(GraphQLEnvelope<[String: String?]>.self, from: Data(contentsOf: url))
		let error = try #require(envelope.errors?.first)
		#expect(error.path == [.field("repository")])
		if case .notFound = error.asTaskError { } else { Issue.record("Expected typed notFound error") }
	}

	@Test("GraphQL paths decode both field names and array indices")
	func heterogeneousErrorPath() throws {
		let data = Data(#"{"message":"bad node","path":["repository","issues","nodes",3]}"#.utf8)
		let error = try JSONDecoder().decode(GraphQLResponseError.self, from: data)
		#expect(error.path == [.field("repository"), .field("issues"), .field("nodes"), .index(3)])
	}

	@Test("Retryability distinguishes transient and invalid-query errors")
	func typedRetryability() {
		let untyped = GraphQLTaskError.operationFailed([.init(message: "temporary")])
		let invalid = GraphQLTaskError.invalidQuery([.init(message: "syntax", type: "GRAPHQL_PARSE_FAILED")])
		#expect(untyped.isRetryable)
		#expect(!invalid.isRetryable)
	}

	@Test("HTTP-200 rate limits reach retryInterval and retry successfully")
	@ConveyActor func retriesRateLimit() async throws {
		struct RetryTask: GraphQLTask {
			typealias GraphQLPayload = ValuePayload
			var configuration: TaskConfiguration?
			var server: ConveyServerable
			var query = "query Value { value }"
			func retryInterval(afterError error: any Error, count: Int) -> TimeInterval? {
				guard case .rateLimited = error as? GraphQLTaskError, count == 1 else { return nil }
				return 0
			}
		}
		GraphQLStubProtocol.reset("retry.example")
		let payload = try await RetryTask(server: GraphQLTestServer(host: "retry.example")).execute()
		#expect(payload.value == "ok")
		#expect(GraphQLStubProtocol.count(for: "retry.example") == 2)
	}
}

@Suite("Cursor pagination", .serialized)
struct GraphQLPaginationTests {
	@Test("Pages stop when hasNextPage is false")
	@ConveyActor func streamsPages() async throws {
		GraphQLStubProtocol.reset("pages.example")
		var pages: [[Int]] = []
		for try await page in PageTask(server: GraphQLTestServer(host: "pages.example"), cursor: nil).pages() { pages.append(page) }
		#expect(pages == [[1, 2], [3, 4]])
		#expect(GraphQLStubProtocol.count(for: "pages.example") == 2)
	}

	@Test("A nil end cursor terminates even when hasNextPage is true")
	@ConveyActor func stopsOnNilCursor() async throws {
		GraphQLStubProtocol.reset("nilcursor.example")
		let nodes = try await PageTask(server: GraphQLTestServer(host: "nilcursor.example"), cursor: nil).allNodes()
		#expect(nodes == [1])
		#expect(GraphQLStubProtocol.count(for: "nilcursor.example") == 1)
	}

	@Test("Node limits stop before issuing another request")
	@ConveyActor func honorsNodeLimitMidPage() async throws {
		GraphQLStubProtocol.reset("pages.example")
		let nodes = try await PageTask(server: GraphQLTestServer(host: "pages.example"), cursor: nil).allNodes(limit: 1)
		#expect(nodes == [1])
		#expect(GraphQLStubProtocol.count(for: "pages.example") == 1)
	}

	@Test("Breaking page consumption cancels further requests")
	@ConveyActor func cancellationStopsRequests() async throws {
		GraphQLStubProtocol.reset("cancel.example")
		for try await page in PageTask(server: GraphQLTestServer(host: "cancel.example"), cursor: nil).pages() {
			#expect(page == [1, 2])
			break
		}
		try await Task.sleep(for: .milliseconds(20))
		#expect(GraphQLStubProtocol.count(for: "cancel.example") == 1)
	}

	@Test("Later page errors propagate after prior pages were yielded")
	@ConveyActor func laterErrorsPropagate() async {
		GraphQLStubProtocol.reset("pageerror.example")
		var received: [[Int]] = []
		do {
			for try await page in PageTask(server: GraphQLTestServer(host: "pageerror.example"), cursor: nil).pages() { received.append(page) }
			Issue.record("Expected the second page to fail")
		} catch {
			#expect(error is GraphQLTaskError)
		}
		#expect(received == [[1, 2]])
	}
}
