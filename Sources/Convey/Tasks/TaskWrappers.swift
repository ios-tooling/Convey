//
//  TaskWrappers.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 4/27/24.
//

import Foundation

@ConveyActor public protocol WrappedServerTask: ServerTask, Sendable {
	associatedtype Wrapped: ServerTask
	var wrapped: Wrapped { get }
	
	var caching: DataCache.Caching { get }
	var decoder: JSONDecoder? { get }
	var preview: PreviewClosure? { get }
	var localFileSource: URL? { get }
	var echo: EchoStyle? { get }
	var redirect: TaskRedirect? { get }
	var timeout: TimeInterval? { get }
}

public struct WrappedPayloadDownloadingTask<Wrapped: PayloadDownloadingTask>: WrappedServerTask, PayloadDownloadingTask, Sendable {
	public typealias DownloadPayload = Wrapped.DownloadPayload
	
	public let wrapped: Wrapped
	
	public let caching: DataCache.Caching
	public let decoder: JSONDecoder?
	public let preview: PreviewClosure?
	public let echo: EchoStyle?
	public let redirect: TaskRedirect?
	public let timeout: TimeInterval?

	init(wrapped: Wrapped, caching: DataCache.Caching = .skipLocal, decoder: JSONDecoder? = nil, preview: PreviewClosure? = nil, echo: EchoStyle? = nil, redirect: TaskRedirect? = nil, timeout: TimeInterval? = nil) {
		self.wrapped = wrapped
		self.caching = caching
		self.decoder = decoder
		self.preview = preview
		self.echo = echo
		self.redirect = redirect
		self.timeout = timeout
	}
}

struct WrappedDataDownloadingTask<Wrapped: ServerTask>: WrappedServerTask, Sendable {
	let wrapped: Wrapped
	
	let caching: DataCache.Caching
	let decoder: JSONDecoder?
	let preview: PreviewClosure?
	let echo: EchoStyle?
	let redirect: TaskRedirect?
	let timeout: TimeInterval?

	init(wrapped: Wrapped, caching: DataCache.Caching = .skipLocal, decoder: JSONDecoder? = nil, preview: PreviewClosure? = nil, echo: EchoStyle? = nil, redirect: TaskRedirect? = nil, timeout: TimeInterval? = nil) {
		self.wrapped = wrapped
		self.caching = caching
		self.decoder = decoder
		self.preview = preview
		self.echo = echo
		self.redirect = redirect
		self.timeout = timeout
	}
}

extension ServerTask {
	var wrappedDecoder: JSONDecoder? { (self as? (any WrappedServerTask))?.decoder }
	var wrappedCaching: DataCache.Caching { (self as? (any WrappedServerTask))?.caching ?? .skipLocal }
	var wrappedPreview: PreviewClosure? { (self as? (any WrappedServerTask))?.preview }
	var wrappedEcho: EchoStyle? { (self as? (any WrappedServerTask))?.echo }
	var wrappedRedirect: TaskRedirect? { (self as? (any WrappedServerTask))?.redirect }
	var wrappedTimeout: TimeInterval? { (self as? (any WrappedServerTask))?.timeout }

	public var wrappedTask: ServerTask {
		if let wrapped = self as? (any WrappedServerTask) { return wrapped.wrapped }
		return self
	}
}
	
public extension ServerTask {
	func decoder(_ decoder: JSONDecoder) -> any ServerTask { copy(decoder: decoder) }
	func caching(_ caching: DataCache.Caching) -> any ServerTask { copy(caching: caching) }
	func preview(_ preview: @escaping PreviewClosure) -> any ServerTask { copy(preview: preview) }
	func echo(_ echo: EchoStyle?) -> any ServerTask { copy(echo: echo) }
	func redirects(_ redirect: TaskRedirect?) -> any ServerTask { redirect?.enabled != false ? copy(redirect: redirect) : self }
	func timeout(_ timeout: TimeInterval) -> any ServerTask { copy(timeout: timeout) }
}

@ConveyActor public extension PayloadDownloadingTask {
	func decoder(_ decoder: JSONDecoder) -> any PayloadDownloadingTask<DownloadPayload> { copy(decoder: decoder) }
	func caching(_ caching: DataCache.Caching) -> any PayloadDownloadingTask<DownloadPayload> { copy(caching: caching) }
	func preview(_ preview: @escaping PreviewClosure) -> any PayloadDownloadingTask<DownloadPayload> { copy(preview: preview) }
	func echo(_ echo: EchoStyle?) -> any PayloadDownloadingTask<DownloadPayload> { copy(echo: echo) }
	func redirects(_ redirect: TaskRedirect?) -> any PayloadDownloadingTask<DownloadPayload> { redirect?.enabled != false ? copy(redirect: redirect) : self }
	func timeout(_ timeout: TimeInterval) -> any PayloadDownloadingTask<DownloadPayload> { copy(timeout: timeout) }
}

@ConveyActor extension WrappedServerTask {
	public var path: String { wrapped.path }
	public func postProcess(response: ServerResponse) async throws { try await wrapped.postProcess(response: response) }
	public var httpMethod: String { wrapped.httpMethod }
	public var server: ConveyServer { wrapped.server }
	public var url: URL { wrapped.url }
	public var taskTag: String { wrapped.taskTag }
	public var localFileSource: URL? { nil }
}

@ConveyActor extension PayloadDownloadingTask {
	func copy(caching: DataCache.Caching? = nil, decoder: JSONDecoder? = nil, preview: PreviewClosure? = nil, echo: EchoStyle? = nil, redirect: TaskRedirect? = nil, timeout: TimeInterval? = nil) -> any PayloadDownloadingTask<DownloadPayload> {
		WrappedPayloadDownloadingTask(wrapped: self, caching: caching ?? wrappedCaching, decoder: decoder ?? wrappedDecoder, preview: preview ?? wrappedPreview, echo: echo ?? wrappedEcho, redirect: redirect ?? wrappedRedirect, timeout: timeout ?? wrappedTimeout)
	}
}

extension ServerTask {
	func copy(caching: DataCache.Caching? = nil, decoder: JSONDecoder? = nil, preview: PreviewClosure? = nil, echo: EchoStyle? = nil, redirect: TaskRedirect? = nil, timeout: TimeInterval? = nil) -> any ServerTask {
		WrappedDataDownloadingTask(wrapped: self, caching: caching ?? wrappedCaching, decoder: decoder ?? wrappedDecoder, preview: preview ?? wrappedPreview, echo: echo ?? wrappedEcho, redirect: redirect ?? wrappedRedirect, timeout: timeout ?? wrappedTimeout)
	}
}
