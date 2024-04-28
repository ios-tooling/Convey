//
//  TaskWrappers.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 4/27/24.
//

import Foundation

struct WrappedPayloadDownloadingTask<Wrapped: PayloadDownloadingTask>: WrappedServerTask, PayloadDownloadingTask, Sendable {
	typealias DownloadPayload = Wrapped.DownloadPayload
	
	let wrapped: Wrapped
	
	let caching: DataCache.Caching
	let decoder: JSONDecoder?
	let preview: PreviewClosure?
	let echoes: Bool
	
	init(wrapped: Wrapped, caching: DataCache.Caching = .skipLocal, decoder: JSONDecoder? = nil, preview: PreviewClosure? = nil, echoes: Bool = false) {
		self.wrapped = wrapped
		self.caching = caching
		self.decoder = decoder
		self.preview = preview
		self.echoes = echoes
	}
}

struct WrappedDataDownloadingTask<Wrapped: ServerTask>: WrappedServerTask, Sendable {
	let wrapped: Wrapped
	
	let caching: DataCache.Caching
	let decoder: JSONDecoder?
	let preview: PreviewClosure?
	let echoes: Bool

	init(wrapped: Wrapped, caching: DataCache.Caching = .skipLocal, decoder: JSONDecoder? = nil, preview: PreviewClosure? = nil, echoes: Bool = true) {
		self.wrapped = wrapped
		self.caching = caching
		self.decoder = decoder
		self.preview = preview
		self.echoes = echoes
	}
}

extension ServerTask {
	var wrappedDecoder: JSONDecoder? { (self as? (any WrappedServerTask))?.decoder }
	var wrappedCaching: DataCache.Caching { (self as? (any WrappedServerTask))?.caching ?? .skipLocal }
	var wrappedPreview: PreviewClosure? { (self as? (any WrappedServerTask))?.preview }
	var wrappedEchoes: Bool { (self as? (any WrappedServerTask))?.echoes ?? false }
}
	
public extension ServerTask {
	func decoder(_ decoder: JSONDecoder) -> any ServerTask {
		WrappedDataDownloadingTask(wrapped: self, caching: wrappedCaching, decoder: decoder, preview: wrappedPreview, echoes: wrappedEchoes)
	}
	
	func caching(_ caching: DataCache.Caching) -> any ServerTask {
		WrappedDataDownloadingTask(wrapped: self, caching: caching, decoder: wrappedDecoder, preview: wrappedPreview, echoes: wrappedEchoes)
	}
	
	func preview(_ preview: @escaping PreviewClosure) -> any ServerTask {
		WrappedDataDownloadingTask(wrapped: self, caching: wrappedCaching, decoder: wrappedDecoder, preview: preview, echoes: wrappedEchoes)
	}
	
	func echoes(_ echoes: Bool) -> any ServerTask {
		WrappedDataDownloadingTask(wrapped: self, caching: wrappedCaching, decoder: wrappedDecoder, preview: wrappedPreview, echoes: echoes)
	}
}

public extension PayloadDownloadingTask {
	func decoder(_ decoder: JSONDecoder) -> any PayloadDownloadingTask<DownloadPayload> {
		WrappedPayloadDownloadingTask(wrapped: self, caching: wrappedCaching, decoder: decoder, preview: wrappedPreview, echoes: wrappedEchoes)
	}
	
	func caching(_ caching: DataCache.Caching) -> any PayloadDownloadingTask<DownloadPayload> {
		WrappedPayloadDownloadingTask(wrapped: self, caching: caching, decoder: wrappedDecoder, preview: wrappedPreview, echoes: wrappedEchoes)
	}
	
	func preview(_ preview: @escaping PreviewClosure) -> any PayloadDownloadingTask<DownloadPayload> {
		WrappedPayloadDownloadingTask(wrapped: self, caching: wrappedCaching, decoder: wrappedDecoder, preview: preview, echoes: wrappedEchoes)
	}
	
	func echoes(_ echoes: Bool) -> any PayloadDownloadingTask<DownloadPayload> {
		WrappedPayloadDownloadingTask(wrapped: self, caching: wrappedCaching, decoder: wrappedDecoder, preview: wrappedPreview, echoes: echoes)
	}
}

protocol WrappedServerTask: ServerTask, Sendable {
	associatedtype Wrapped: ServerTask
	var wrapped: Wrapped { get }
	
	var caching: DataCache.Caching { get }
	var decoder: JSONDecoder? { get }
	var preview: PreviewClosure? { get }
	var localFileSource: URL? { get }
	var echoes: Bool { get }

}

extension WrappedServerTask {
	var path: String { wrapped.path }
	func postProcess(response: ServerReturned) async throws { try await wrapped.postProcess(response: response) }
	var httpMethod: String { wrapped.httpMethod }
	var server: ConveyServer { wrapped.server }
	var url: URL { wrapped.url }
	var taskTag: String { wrapped.taskTag }
	var localFileSource: URL? { nil }
}
