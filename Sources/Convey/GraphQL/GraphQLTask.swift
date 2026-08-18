import Foundation

@ConveyActor public protocol GraphQLTask<GraphQLPayload>: UploadingTask
	where UploadPayload == Data, DownloadPayload == GraphQLEnvelope<GraphQLPayload> {
	associatedtype GraphQLPayload: Decodable & Sendable
	var query: String { get }
	var variables: GraphQLVariables? { get }
	var operationName: String? { get }
	var fragments: [GraphQLFragment] { get }
	var allowsPartialResults: Bool { get }
	var redactedVariables: Set<String> { get }
}

private struct GraphQLRequestBody: Encodable, Sendable {
	let query: String
	let variables: GraphQLVariables?
	let operationName: String?
}

private struct GraphQLErrorProbe: Decodable {
	let errors: [GraphQLResponseError]?
}

public extension GraphQLTask {
	var method: HTTPMethod { .post }
	var path: String { "" }
	var url: URL { get async { server.baseURL } }
	var contentType: String? { "application/json" }
	var acceptType: String { "application/json" }
	var variables: GraphQLVariables? { nil }
	var operationName: String? { nil }
	var fragments: [GraphQLFragment] { [] }
	var allowsPartialResults: Bool { false }
	var redactedVariables: Set<String> { [] }
	var uploadPayload: Data? { nil }

	var fullQueryDocument: String {
		get throws { try GraphQLFragmentComposer.compose(query: query, fragments: fragments) }
	}

	var uploadData: Data? {
		get throws {
			let encoder = requestEncoder()
			return try encoder.encode(GraphQLRequestBody(query: try fullQueryDocument, variables: variables, operationName: operationName))
		}
	}

	func executeEnvelope() async throws -> ServerResponse<GraphQLEnvelope<GraphQLPayload>> {
		try await download()
	}

	func execute() async throws -> GraphQLPayload {
		let envelope = try await executeEnvelope().payload
		if let errors = envelope.errors, !errors.isEmpty {
			if allowsPartialResults, let data = envelope.data { return data }
			throw GraphQLTaskError.mapping(errors)
		}
		guard let data = envelope.data else { throw GraphQLTaskError.missingData }
		return data
	}

	func operationError(response: URLResponse, data: Data) throws -> (any Error)? {
		let probe = try decoder.decode(GraphQLErrorProbe.self, from: data)
		guard let errors = probe.errors, !errors.isEmpty else { return nil }
		if allowsPartialResults,
			let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
			let value = object["data"], !(value is NSNull) { return nil }
		return GraphQLTaskError.mapping(errors)
	}

	func echoText(for data: Data?) -> String {
		var parts = [(try? fullQueryDocument) ?? query]
		if let variables, let encoded = try? requestEncoder().encode(variables),
			var object = try? JSONSerialization.jsonObject(with: encoded) as? [String: Any] {
			for key in redactedVariables where object[key] != nil { object[key] = "<redacted>" }
			if let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
				let text = String(data: pretty, encoding: .utf8) {
				parts.append("variables: \(text)")
			}
		}
		return parts.joined(separator: "\n")
	}

	func formattedRequestEcho(responseData: Data?) -> String? { echoText(for: responseData) }

	private func requestEncoder() -> JSONEncoder {
		let result = JSONEncoder()
		result.outputFormatting = encoder.outputFormatting.union(.sortedKeys)
		result.dateEncodingStrategy = encoder.dateEncodingStrategy
		result.dataEncodingStrategy = encoder.dataEncodingStrategy
		result.nonConformingFloatEncodingStrategy = encoder.nonConformingFloatEncodingStrategy
		result.keyEncodingStrategy = encoder.keyEncodingStrategy
		result.userInfo = encoder.userInfo
		return result
	}
}
