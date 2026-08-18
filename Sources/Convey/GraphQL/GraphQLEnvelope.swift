import Foundation

public struct GraphQLEnvelope<Payload: Decodable & Sendable>: Decodable, Sendable {
	public let data: Payload?
	public let errors: [GraphQLResponseError]?
	public let extensions: GraphQLExtensions?

	public var hasErrors: Bool { errors?.isEmpty == false }

	public init(data: Payload?, errors: [GraphQLResponseError]? = nil, extensions: GraphQLExtensions? = nil) {
		self.data = data
		self.errors = errors
		self.extensions = extensions
	}
}

public typealias GraphQLExtensions = [String: GraphQLJSONValue]

public enum GraphQLJSONValue: Codable, Sendable, Equatable {
	case string(String), number(Double), bool(Bool), null
	case list([GraphQLJSONValue]), object([String: GraphQLJSONValue])

	public init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		if container.decodeNil() { self = .null }
		else if let value = try? container.decode(Bool.self) { self = .bool(value) }
		else if let value = try? container.decode(Double.self) { self = .number(value) }
		else if let value = try? container.decode(String.self) { self = .string(value) }
		else if let value = try? container.decode([GraphQLJSONValue].self) { self = .list(value) }
		else { self = .object(try container.decode([String: GraphQLJSONValue].self)) }
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		switch self {
		case .string(let value): try container.encode(value)
		case .number(let value): try container.encode(value)
		case .bool(let value): try container.encode(value)
		case .null: try container.encodeNil()
		case .list(let value): try container.encode(value)
		case .object(let value): try container.encode(value)
		}
	}
}

public struct GraphQLResponseError: Decodable, Sendable, Equatable {
	public struct Location: Decodable, Sendable, Equatable {
		public let line: Int
		public let column: Int
		public init(line: Int, column: Int) { self.line = line; self.column = column }
	}

	public let message: String
	public let type: String?
	public let path: [GraphQLPathComponent]?
	public let locations: [Location]?
	public let extensions: GraphQLExtensions?

	public init(message: String, type: String? = nil, path: [GraphQLPathComponent]? = nil, locations: [Location]? = nil, extensions: GraphQLExtensions? = nil) {
		self.message = message
		self.type = type
		self.path = path
		self.locations = locations
		self.extensions = extensions
	}

	private enum CodingKeys: String, CodingKey { case message, type, path, locations, extensions }

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		message = try container.decode(String.self, forKey: .message)
		extensions = try container.decodeIfPresent(GraphQLExtensions.self, forKey: .extensions)
		type = try container.decodeIfPresent(String.self, forKey: .type)
			?? extensions?["type"]?.stringValue
		path = try container.decodeIfPresent([GraphQLPathComponent].self, forKey: .path)
		locations = try container.decodeIfPresent([Location].self, forKey: .locations)
	}
}

public enum GraphQLPathComponent: Decodable, Sendable, Equatable {
	case field(String)
	case index(Int)

	public init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		if let field = try? container.decode(String.self) { self = .field(field); return }
		if let index = try? container.decode(Int.self) { self = .index(index); return }
		throw DecodingError.typeMismatch(Self.self, .init(codingPath: decoder.codingPath, debugDescription: "GraphQL paths contain only field names and integer indices."))
	}
}

private extension GraphQLJSONValue {
	var stringValue: String? { if case .string(let value) = self { value } else { nil } }
}
