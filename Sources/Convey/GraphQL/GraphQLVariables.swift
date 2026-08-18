import Foundation

public struct GraphQLVariables: Encodable, Sendable, ExpressibleByDictionaryLiteral {
	private enum Storage: Sendable {
		case values([String: GraphQLValue])
		case encodable(@Sendable (Encoder) throws -> Void)
	}

	private var storage: Storage

	public init(_ values: [String: GraphQLValue]) {
		storage = .values(values)
	}

	public init(dictionaryLiteral elements: (String, GraphQLValue)...) {
		storage = .values(Dictionary(uniqueKeysWithValues: elements))
	}

	public init<E: Encodable & Sendable>(encoding value: E) {
		storage = .encodable { encoder in try value.encode(to: encoder) }
	}

	public subscript(key: String) -> GraphQLValue? {
		get {
			guard case .values(let values) = storage else { return nil }
			return values[key]
		}
		set {
			var values: [String: GraphQLValue]
			if case .values(let existing) = storage { values = existing } else { values = [:] }
			values[key] = newValue
			storage = .values(values)
		}
	}

	public func encode(to encoder: Encoder) throws {
		switch storage {
		case .values(let values):
			var container = encoder.container(keyedBy: DynamicCodingKey.self)
			for key in values.keys.sorted() {
				try container.encode(values[key], forKey: DynamicCodingKey(key))
			}
		case .encodable(let encode):
			try encode(encoder)
		}
	}
}

public enum GraphQLValue: Encodable, Sendable,
	ExpressibleByStringLiteral, ExpressibleByIntegerLiteral,
	ExpressibleByFloatLiteral, ExpressibleByBooleanLiteral,
	ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral,
	ExpressibleByNilLiteral {
	case string(String)
	case int(Int)
	case double(Double)
	case bool(Bool)
	case null
	case list([GraphQLValue])
	case object([String: GraphQLValue])
	case encodable(any Encodable & Sendable)

	public init(stringLiteral value: String) { self = .string(value) }
	public init(integerLiteral value: Int) { self = .int(value) }
	public init(floatLiteral value: Double) { self = .double(value) }
	public init(booleanLiteral value: Bool) { self = .bool(value) }
	public init(arrayLiteral elements: GraphQLValue...) { self = .list(elements) }
	public init(dictionaryLiteral elements: (String, GraphQLValue)...) {
		self = .object(Dictionary(uniqueKeysWithValues: elements))
	}
	public init(nilLiteral: ()) { self = .null }

	public func encode(to encoder: Encoder) throws {
		switch self {
		case .string(let value): var c = encoder.singleValueContainer(); try c.encode(value)
		case .int(let value): var c = encoder.singleValueContainer(); try c.encode(value)
		case .double(let value): var c = encoder.singleValueContainer(); try c.encode(value)
		case .bool(let value): var c = encoder.singleValueContainer(); try c.encode(value)
		case .null: var c = encoder.singleValueContainer(); try c.encodeNil()
		case .list(let value): var c = encoder.singleValueContainer(); try c.encode(value)
		case .object(let value):
			var c = encoder.container(keyedBy: DynamicCodingKey.self)
			for key in value.keys.sorted() { try c.encode(value[key], forKey: DynamicCodingKey(key)) }
		case .encodable(let value): try value.encode(to: encoder)
		}
	}
}

private struct DynamicCodingKey: CodingKey {
	let stringValue: String
	let intValue: Int? = nil
	init(_ value: String) { stringValue = value }
	init?(stringValue: String) { self.init(stringValue) }
	init?(intValue: Int) { return nil }
}
