import Foundation

public enum GraphQLTaskError: Error, Sendable {
	case operationFailed([GraphQLResponseError])
	case missingData
	case notFound(GraphQLResponseError)
	case forbidden(GraphQLResponseError)
	case rateLimited(GraphQLResponseError, retryAfter: TimeInterval?)
	case unauthenticated(GraphQLResponseError)
	case invalidQuery([GraphQLResponseError])

	public var responseErrors: [GraphQLResponseError] {
		switch self {
		case .operationFailed(let errors), .invalidQuery(let errors): errors
		case .notFound(let error), .forbidden(let error), .rateLimited(let error, _), .unauthenticated(let error): [error]
		case .missingData: []
		}
	}

	public var isRetryable: Bool {
		switch self {
		case .rateLimited: true
		case .operationFailed(let errors): errors.contains { $0.type == nil }
		default: false
		}
	}

	static func mapping(_ errors: [GraphQLResponseError]) -> GraphQLTaskError {
		guard errors.count == 1, let error = errors.first else { return .operationFailed(errors) }
		return error.asTaskError
	}
}

extension GraphQLTaskError: LocalizedError {
	public var errorDescription: String? {
		switch self {
		case .missingData: "The GraphQL response contained neither data nor errors."
		case .operationFailed(let errors), .invalidQuery(let errors): errors.map(\.message).joined(separator: "\n")
		case .notFound(let error), .forbidden(let error), .rateLimited(let error, _), .unauthenticated(let error): error.message
		}
	}
}

public extension GraphQLResponseError {
	var asTaskError: GraphQLTaskError {
		switch type?.uppercased() {
		case "NOT_FOUND": .notFound(self)
		case "FORBIDDEN": .forbidden(self)
		case "RATE_LIMITED": .rateLimited(self, retryAfter: retryAfter)
		case "UNAUTHENTICATED", "AUTHENTICATION_ERROR": .unauthenticated(self)
		case "GRAPHQL_PARSE_FAILED", "GRAPHQL_VALIDATION_FAILED", "INVALID_QUERY": .invalidQuery([self])
		default: .operationFailed([self])
		}
	}

	private var retryAfter: TimeInterval? {
		guard let value = extensions?["retryAfter"] ?? extensions?["retry_after"] else { return nil }
		switch value {
		case .number(let value): return value
		case .string(let value): return TimeInterval(value)
		default: return nil
		}
	}
}
