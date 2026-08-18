import Foundation

public struct GraphQLFragment: Sendable, Hashable {
	public let name: String
	public let text: String
	public let dependencies: [GraphQLFragment]

	public init(name: String, dependencies: [GraphQLFragment] = [], text: String) {
		self.name = name
		self.dependencies = dependencies
		self.text = text
	}
}

public enum GraphQLFragmentError: Error, Sendable, Equatable, LocalizedError {
	case cyclicDependency([String])
	case conflictingDefinitions(String)

	public var errorDescription: String? {
		switch self {
		case .cyclicDependency(let path): "Cyclic GraphQL fragment dependency: \(path.joined(separator: " -> "))"
		case .conflictingDefinitions(let name): "GraphQL fragment '\(name)' has conflicting definitions."
		}
	}
}

enum GraphQLFragmentComposer {
	static func compose(query: String, fragments: [GraphQLFragment]) throws -> String {
		guard !fragments.isEmpty else { return query }
		var definitions: [String: GraphQLFragment] = [:]
		var visiting: [String] = []
		var complete: Set<String> = []

		func visit(_ fragment: GraphQLFragment) throws {
			if let index = visiting.firstIndex(of: fragment.name) {
				throw GraphQLFragmentError.cyclicDependency(Array(visiting[index...]) + [fragment.name])
			}
			if let existing = definitions[fragment.name], existing.text != fragment.text {
				throw GraphQLFragmentError.conflictingDefinitions(fragment.name)
			}
			if complete.contains(fragment.name) { return }
			definitions[fragment.name] = fragment
			visiting.append(fragment.name)
			for dependency in fragment.dependencies.sorted(by: { $0.name < $1.name }) { try visit(dependency) }
			visiting.removeLast()
			complete.insert(fragment.name)
		}

		for fragment in fragments.sorted(by: { $0.name < $1.name }) { try visit(fragment) }
		let suffix = definitions.values.sorted(by: { $0.name < $1.name }).map(\.text).joined(separator: "\n\n")
		return query + "\n\n" + suffix
	}
}

public enum GraphQLDocument {
	public static func named(_ name: String, in bundle: Bundle) -> String {
		guard let url = bundle.url(forResource: name, withExtension: "graphql") else {
			preconditionFailure("Missing GraphQL document resource: \(name).graphql")
		}
		do { return try String(contentsOf: url, encoding: .utf8) }
		catch { preconditionFailure("Unable to read GraphQL document \(name).graphql: \(error)") }
	}
}
