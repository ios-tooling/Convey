//
//  TaskWrappers.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 4/27/24.
//

import Foundation

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
	var wrappedDecoder: JSONDecoder? { (self as? (any WrappedServerTask))?.decoder }
	var wrappedCaching: DataCache.Caching { (self as? (any WrappedServerTask))?.caching ?? .skipLocal }
	var wrappedPreview: PreviewClosure? { (self as? (any WrappedServerTask))?.preview }
	var wrappedEchoes: Bool { (self as? (any WrappedServerTask))?.echoes ?? false }
	var wrappedRedirect: TaskRedirect? { (self as? (any WrappedServerTask))?.redirect }
	var wrappedTimeout: TimeInterval? { (self as? (any WrappedServerTask))?.timeout }

	var wrappedTask: ServerTask {
		if let wrapped = self as? (any WrappedServerTask) { return wrapped.wrapped }
		return self
	}
}
	
public extension ServerTask {
	func decoder(_ decoder: JSONDecoder) -> any ServerTask { copy(decoder: decoder) }
	func caching(_ caching: DataCache.Caching) -> any ServerTask { copy(caching: caching) }
	func preview(_ preview: @escaping PreviewClosure) -> any ServerTask { copy(preview: preview) }
	func echoes(_ echoes: Bool) -> any ServerTask { copy(echoes: echoes) }
	func redirects(_ redirect: TaskRedirect?) -> any ServerTask { redirect?.enabled != false ? copy(redirect: redirect) : self }
	func timeout(_ timeout: TimeInterval) -> any ServerTask { copy(timeout: timeout) }
}

public extension PayloadDownloadingTask {
	func decoder(_ decoder: JSONDecoder) -> any PayloadDownloadingTask<DownloadPayload> { copy(decoder: decoder) }
	func caching(_ caching: DataCache.Caching) -> any PayloadDownloadingTask<DownloadPayload> { copy(caching: caching) }
	func preview(_ preview: @escaping PreviewClosure) -> any PayloadDownloadingTask<DownloadPayload> { copy(preview: preview) }
	func echoes(_ echoes: Bool) -> any PayloadDownloadingTask<DownloadPayload> { copy(echoes: echoes) }
	func redirects(_ redirect: TaskRedirect?) -> any PayloadDownloadingTask<DownloadPayload> { redirect?.enabled != false ? copy(redirect: redirect) : self }
	func timeout(_ timeout: TimeInterval) -> any PayloadDownloadingTask<DownloadPayload> { copy(timeout: timeout) }
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

extension PayloadDownloadingTask {
	func copy(caching: DataCache.Caching? = nil, decoder: JSONDecoder? = nil, preview: PreviewClosure? = nil, echoes: Bool? = nil, redirect: TaskRedirect? = nil, timeout: TimeInterval? = nil) -> any PayloadDownloadingTask<DownloadPayload> {
		WrappedPayloadDownloadingTask(wrapped: self, caching: caching ?? wrappedCaching, decoder: decoder ?? wrappedDecoder, preview: preview ?? wrappedPreview, echoes: echoes ?? wrappedEchoes, redirect: redirect ?? wrappedRedirect, timeout: timeout ?? wrappedTimeout)
	}
}

extension ServerTask {
	func copy(caching: DataCache.Caching? = nil, decoder: JSONDecoder? = nil, preview: PreviewClosure? = nil, echoes: Bool? = nil, redirect: TaskRedirect? = nil, timeout: TimeInterval? = nil) -> any ServerTask {
		WrappedDataDownloadingTask(wrapped: self, caching: caching ?? wrappedCaching, decoder: decoder ?? wrappedDecoder, preview: preview ?? wrappedPreview, echoes: echoes ?? wrappedEchoes, redirect: redirect ?? wrappedRedirect, timeout: timeout ?? wrappedTimeout)
	}
}
