import Foundation

public struct GraphQLConnection<Node: Decodable & Sendable>: Decodable, Sendable {
	public let nodes: [Node]
	public let pageInfo: GraphQLPageInfo
	public let totalCount: Int?

	public init(nodes: [Node], pageInfo: GraphQLPageInfo, totalCount: Int? = nil) {
		self.nodes = nodes
		self.pageInfo = pageInfo
		self.totalCount = totalCount
	}
}

public struct GraphQLPageInfo: Decodable, Sendable {
	public let hasNextPage: Bool
	public let hasPreviousPage: Bool
	public let startCursor: String?
	public let endCursor: String?

	public init(hasNextPage: Bool, hasPreviousPage: Bool = false, startCursor: String? = nil, endCursor: String? = nil) {
		self.hasNextPage = hasNextPage
		self.hasPreviousPage = hasPreviousPage
		self.startCursor = startCursor
		self.endCursor = endCursor
	}
}

@ConveyActor public protocol PaginatedGraphQLTask: GraphQLTask {
	associatedtype PageNode: Decodable & Sendable
	var cursor: String? { get }
	func withCursor(_ cursor: String?) -> Self
	func connection(from payload: GraphQLPayload) -> GraphQLConnection<PageNode>
}

public extension PaginatedGraphQLTask {
	func pages() -> AsyncThrowingStream<[PageNode], any Error> {
		AsyncThrowingStream { continuation in
			let producer = Task { @ConveyActor in
				do {
					var current = self
					while !Task.isCancelled {
						let payload = try await current.execute()
						let page = current.connection(from: payload)
						continuation.yield(page.nodes)
						guard page.pageInfo.hasNextPage, let next = page.pageInfo.endCursor else { break }
						try Task.checkCancellation()
						current = current.withCursor(next)
						await Task.yield()
					}
					continuation.finish()
				} catch is CancellationError {
					continuation.finish()
				} catch {
					continuation.finish(throwing: error)
				}
			}
			continuation.onTermination = { @Sendable _ in producer.cancel() }
		}
	}

	func allNodes(limit: Int? = nil) async throws -> [PageNode] {
		if let limit, limit <= 0 { return [] }
		var result: [PageNode] = []
		var current = self
		while true {
			try Task.checkCancellation()
			let payload = try await current.execute()
			let page = current.connection(from: payload)
			if let limit {
				result.append(contentsOf: page.nodes.prefix(limit - result.count))
				if result.count >= limit { return result }
			} else {
				result.append(contentsOf: page.nodes)
			}
			guard page.pageInfo.hasNextPage, let next = page.pageInfo.endCursor else { return result }
			current = current.withCursor(next)
		}
	}
}
