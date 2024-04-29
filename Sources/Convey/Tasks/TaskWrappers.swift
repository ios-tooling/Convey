//
//  TaskWrappers.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 4/27/24.
//

import Foundation

public enum TaskRedirect: Sendable { case bundle(String) }

public protocol WrappedServerTask: ServerTask, Sendable {
	associatedtype Wrapped: ServerTask
	var wrapped: Wrapped { get }
	
	var caching: DataCache.Caching { get }
	var decoder: JSONDecoder? { get }
	var preview: PreviewClosure? { get }
	var localFileSource: URL? { get }
	var echoes: Bool { get }
	var redirect: TaskRedirect? { get }
	var timeout: TimeInterval? { get }
}

public struct WrappedPayloadDownloadingTask<Wrapped: PayloadDownloadingTask>: WrappedServerTask, PayloadDownloadingTask, Sendable {
	public typealias DownloadPayload = Wrapped.DownloadPayload
	
	public let wrapped: Wrapped
	
	public let caching: DataCache.Caching
	public let decoder: JSONDecoder?
	public let preview: PreviewClosure?
	public let echoes: Bool
	public let redirect: TaskRedirect?
	public let timeout: TimeInterval?

	init(wrapped: Wrapped, caching: DataCache.Caching = .skipLocal, decoder: JSONDecoder? = nil, preview: PreviewClosure? = nil, echoes: Bool = false, redirect: TaskRedirect? = nil, timeout: TimeInterval? = nil) {
		self.wrapped = wrapped
		self.caching = caching
		self.decoder = decoder
		self.preview = preview
		self.echoes = echoes
		self.redirect = redirect
		self.timeout = timeout
	}
}

struct WrappedDataDownloadingTask<Wrapped: ServerTask>: WrappedServerTask, Sendable {
	let wrapped: Wrapped
	
	let caching: DataCache.Caching
	let decoder: JSONDecoder?
	let preview: PreviewClosure?
	let echoes: Bool
	let redirect: TaskRedirect?
	let timeout: TimeInterval?

	init(wrapped: Wrapped, caching: DataCache.Caching = .skipLocal, decoder: JSONDecoder? = nil, preview: PreviewClosure? = nil, echoes: Bool = true, redirect: TaskRedirect? = nil, timeout: TimeInterval? = nil) {
		self.wrapped = wrapped
		self.caching = caching
		self.decoder = decoder
		self.preview = preview
		self.echoes = echoes
		self.redirect = redirect
		self.timeout = timeout
	}
}

extension ServerTask {
	var wrappedDecoder: JSONDecoder? { (self.wrappedTask as? (any WrappedServerTask))?.decoder }
	var wrappedCaching: DataCache.Caching { (self.wrappedTask as? (any WrappedServerTask))?.caching ?? .skipLocal }
	var wrappedPreview: PreviewClosure? { (self.wrappedTask as? (any WrappedServerTask))?.preview }
	var wrappedEchoes: Bool { (self.wrappedTask as? (any WrappedServerTask))?.echoes ?? false }
	var wrappedRedirect: TaskRedirect? { (self.wrappedTask as? (any WrappedServerTask))?.redirect }
	var wrappedTimeout: TimeInterval? { (self.wrappedTask as? (any WrappedServerTask))?.timeout }

	var wrappedTask: ServerTask {
		if let wrapped = self as? (any WrappedServerTask) { return wrapped.wrapped }
		return self
	}
}
	
public extension ServerTask {
	func decoder(_ decoder: JSONDecoder) -> any ServerTask {
		WrappedDataDownloadingTask(wrapped: self, caching: wrappedCaching, decoder: decoder, preview: wrappedPreview, echoes: wrappedEchoes, redirect: wrappedRedirect, timeout: wrappedTimeout)
	}
	
	func caching(_ caching: DataCache.Caching) -> any ServerTask {
		WrappedDataDownloadingTask(wrapped: self, caching: caching, decoder: wrappedDecoder, preview: wrappedPreview, echoes: wrappedEchoes, redirect: wrappedRedirect, timeout: wrappedTimeout)
	}
	
	func preview(_ preview: @escaping PreviewClosure) -> any ServerTask {
		WrappedDataDownloadingTask(wrapped: self, caching: wrappedCaching, decoder: wrappedDecoder, preview: preview, echoes: wrappedEchoes, redirect: wrappedRedirect, timeout: wrappedTimeout)
	}
	
	func echoes(_ echoes: Bool) -> any ServerTask {
		WrappedDataDownloadingTask(wrapped: self, caching: wrappedCaching, decoder: wrappedDecoder, preview: wrappedPreview, echoes: echoes, redirect: wrappedRedirect, timeout: wrappedTimeout)
	}
	
	func redirects(_ redirect: TaskRedirect) -> any ServerTask {
		WrappedDataDownloadingTask(wrapped: self, caching: wrappedCaching, decoder: wrappedDecoder, preview: wrappedPreview, echoes: wrappedEchoes, redirect: redirect, timeout: wrappedTimeout)
	}
	
	func timeout(_ timeout: TimeInterval) -> any ServerTask {
		WrappedDataDownloadingTask(wrapped: self, caching: wrappedCaching, decoder: wrappedDecoder, preview: wrappedPreview, echoes: wrappedEchoes, redirect: wrappedRedirect, timeout: timeout)
	}
}

public extension PayloadDownloadingTask {
	func decoder(_ decoder: JSONDecoder) -> any PayloadDownloadingTask<DownloadPayload> {
		WrappedPayloadDownloadingTask(wrapped: self, caching: wrappedCaching, decoder: decoder, preview: wrappedPreview, echoes: wrappedEchoes, redirect: wrappedRedirect, timeout: wrappedTimeout)
	}
	
	func caching(_ caching: DataCache.Caching) -> any PayloadDownloadingTask<DownloadPayload> {
		WrappedPayloadDownloadingTask(wrapped: self, caching: caching, decoder: wrappedDecoder, preview: wrappedPreview, echoes: wrappedEchoes, redirect: wrappedRedirect, timeout: wrappedTimeout)
	}
	
	func preview(_ preview: @escaping PreviewClosure) -> any PayloadDownloadingTask<DownloadPayload> {
		WrappedPayloadDownloadingTask(wrapped: self, caching: wrappedCaching, decoder: wrappedDecoder, preview: preview, echoes: wrappedEchoes, redirect: wrappedRedirect, timeout: wrappedTimeout)
	}
	
	func echoes(_ echoes: Bool) -> any PayloadDownloadingTask<DownloadPayload> {
		WrappedPayloadDownloadingTask(wrapped: self, caching: wrappedCaching, decoder: wrappedDecoder, preview: wrappedPreview, echoes: echoes, redirect: wrappedRedirect, timeout: wrappedTimeout)
	}
	
	func redirects(_ redirect: TaskRedirect) -> any ServerTask {
		WrappedPayloadDownloadingTask(wrapped: self, caching: wrappedCaching, decoder: wrappedDecoder, preview: wrappedPreview, echoes: wrappedEchoes, redirect: redirect, timeout: wrappedTimeout)
	}
	
	func timeout(_ timeout: TimeInterval) -> any ServerTask {
		WrappedPayloadDownloadingTask(wrapped: self, caching: wrappedCaching, decoder: wrappedDecoder, preview: wrappedPreview, echoes: wrappedEchoes, redirect: wrappedRedirect, timeout: timeout)
	}
}

extension WrappedServerTask {
	public var path: String { wrapped.path }
	public func postProcess(response: ServerResponse) async throws { try await wrapped.postProcess(response: response) }
	public var httpMethod: String { wrapped.httpMethod }
	public var server: ConveyServer { wrapped.server }
	public var url: URL { wrapped.url }
	public var taskTag: String { wrapped.taskTag }
	public var localFileSource: URL? { nil }
}
