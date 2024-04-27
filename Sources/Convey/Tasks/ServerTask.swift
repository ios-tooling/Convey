//
//  ServerTask.swift
//  ServerTask
//
//  Created by Ben Gottlieb on 9/11/21.
//

import Foundation

public typealias PreviewClosure = @Sendable (ServerReturned) -> Void

public protocol ServerTask: Sendable {
	var path: String { get }
	func postProcess(response: ServerReturned) async throws
	var httpMethod: String { get }
	var server: ConveyServer { get }
	var url: URL { get }
	var taskTag: String { get }
}

public protocol DownloadableEntity {
	
}

public protocol PayloadDownloadable: ServerTask {
	associatedtype DownloadPayload: Decodable
	func postProcess(payload: DownloadPayload) async throws
}

public struct WrappedPayloadDownloadingTask<Wrapped: PayloadDownloadable>: WrappedServerTask, PayloadDownloadable, Sendable {
	public typealias DownloadPayload = Wrapped.DownloadPayload
	
	public let wrapped: Wrapped
	
	public let caching: DataCache.Caching
	public let decoder: JSONDecoder?
	public let preview: PreviewClosure?
	
	init(wrapped: Wrapped, caching: DataCache.Caching = .skipLocal, decoder: JSONDecoder? = nil, preview: PreviewClosure? = nil) {
		self.wrapped = wrapped
		self.caching = caching
		self.decoder = decoder
		self.preview = preview
	}
}

public struct WrappedDataDownloadingTask<Wrapped: ServerTask>: WrappedServerTask, Sendable {
	public let wrapped: Wrapped
	
	public let caching: DataCache.Caching
	public let decoder: JSONDecoder?
	public let preview: PreviewClosure?

	init(wrapped: Wrapped, caching: DataCache.Caching = .skipLocal, decoder: JSONDecoder? = nil, preview: PreviewClosure? = nil) {
		self.wrapped = wrapped
		self.caching = caching
		self.decoder = decoder
		self.preview = preview
	}
}



public protocol WrappedServerTask: ServerTask, Sendable {
	associatedtype Wrapped: ServerTask
	var wrapped: Wrapped { get }
	
	var caching: DataCache.Caching { get }
	var decoder: JSONDecoder? { get }
	var preview: PreviewClosure? { get }
}

extension WrappedServerTask {
	public var path: String { wrapped.path }
	public func postProcess(response: ServerReturned) async throws { try await wrapped.postProcess(response: response) }
	public var httpMethod: String { wrapped.httpMethod }
	public var server: ConveyServer { wrapped.server }
	public var url: URL { wrapped.url }
	public var taskTag: String { wrapped.taskTag }
}
