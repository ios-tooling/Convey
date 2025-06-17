//
//  ServerTaskContainer.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 11/23/24.
//

import Foundation

public struct RequestOptions {
	let sourceFileURL: URL?
	
	public init(sourceURL: URL? = nil) {
		self.sourceFileURL = sourceURL
	}
}

@ConveyActor public struct ServerTaskContainer<RootTask: ServerTask>: ServerConveyable, Sendable {
	public typealias UnderlyingTask = RootTask
	let root: RootTask
	
	init(root: RootTask) {
		self.root = root
	}
	
	public var customURL: URL? { get { root.customURL }}
	public var caching: DataCache.Caching { root.caching }
	public var wrappedTask: RootTask { root }
	public var path: String { root.path }
	public func postProcess(response: ServerResponse) async throws { try await root.postProcess(response: response) }
	public var httpMethod: String { root.httpMethod }
	public var server: ConveyServer { root.server }
	public var url: URL { root.url }
	public var taskTag: String { root.taskTag }
	public var timeout: TimeInterval { get async { await root.timeout } }
	
	public func willStart() async {
		await root.willStart()
		extraWillStart?()
	}
	public func didStart() async { await root.didStart() }
	public func preFlight() async throws { try await root.preFlight() }
	public func postFlight() async throws { try await root.postFlight() }
	public var preview: PreviewClosure? { root.preview }

	public func willComplete(with: ServerResponse) async { await root.willComplete(with: with) }
	public func didComplete(with response: ServerResponse) async {
		await root.didComplete(with: response)
		extraDidComplete?(response)
	}
	public var headers: ConveyHeaders { additionalHeaders + root.headers }
	public var parameters: TaskURLParameters? { additionalParameters + root.parameters }

	public func didFail(with error: Error) async { await root.didFail(with: error) }
	
	public func buildRequest() async throws -> URLRequest { try await root.buildRequest() }
	public var cookies: [HTTPCookie]? { root.cookies }
	public var encoder: JSONEncoder { overrideEncoder ?? root.encoder }
	public var decoder: JSONDecoder { overrideDecoder ?? root.decoder }
	public var reportBadHTTPStatusAsError: Bool { overridReportBadHTTPStatusAsError ?? root.reportBadHTTPStatusAsError }
	public var echoing: ConveyEchoStyle? { echoingOverride ?? root.echoing }
	public var requestOptions: RequestOptions? { requestOptionsOverride ?? root.requestOptions }

	
	public func add(echoing: ConveyEchoStyle? = nil, timeout: TimeInterval? = nil, caching: DataCache.Caching? = nil, headers: ConveyHeaders? = nil, parameters: TaskURLParameters? = nil, reportBadHTTPStatusAsError: Bool? = nil, encoder: JSONEncoder? = nil, decoder: JSONDecoder? = nil, willStart: (() -> Void)? = nil, didComplete: ((ServerResponse) -> Void)? = nil) -> ServerTaskContainer {
		var copy = self
		
		if let echoing { copy.echoingOverride = echoing }
		if let timeout { copy.timeoutOverride = timeout }
		if let caching { copy.cachingOverride = caching }
		if let headers { copy.additionalHeaders = headers }
		if let parameters { copy.additionalParameters = parameters }
		if let reportBadHTTPStatusAsError { copy.overridReportBadHTTPStatusAsError = reportBadHTTPStatusAsError }
		if let encoder { copy.overrideEncoder = encoder }
		if let decoder { copy.overrideDecoder = decoder }
		if let willStart { copy.extraWillStart = willStart }
		if let didComplete { copy.extraDidComplete = didComplete }
		if let requestOptions { copy.requestOptionsOverride = requestOptions }

		return copy
	}
	
	public func echo(_ echoing: ConveyEchoStyle? = .always) -> Self { add(echoing: echoing) }
	public func timeout(_ timeout: TimeInterval?) -> Self { add(timeout: timeout) }
	public func caching(_ caching: DataCache.Caching?) -> Self { add(caching: caching) }
	public func headers(_ headers: ConveyHeaders?) -> Self { add(headers: headers) }
	public func parameters(_ parameters: TaskURLParameters?) -> Self { add(parameters: parameters) }
	public func reportBadHTTPStatusAsError(_ report: Bool? = true) -> Self { add(reportBadHTTPStatusAsError: report) }
	public func encoder(_ encoder: JSONEncoder?) -> Self { add(encoder: encoder) }
	public func decoder(_ encoder: JSONDecoder?) -> Self { add(decoder: decoder) }
	public func didComplete(_ didComplete: ((ServerResponse) -> Void)?) -> Self { add(didComplete: didComplete) }
	public func willStart(_ willStart: (() -> Void)?) -> Self { add(willStart: willStart) }

	var echoingOverride: ConveyEchoStyle?
	var timeoutOverride: TimeInterval?
	var cachingOverride: DataCache.Caching?
	var additionalHeaders: ConveyHeaders?
	var additionalParameters: TaskURLParameters?
	var overridReportBadHTTPStatusAsError: Bool?
	var overrideEncoder: JSONEncoder?
	var overrideDecoder: JSONDecoder?
	var extraDidComplete: ((ServerResponse) -> Void)?
	var extraWillStart: (() -> Void)?
	var requestOptionsOverride: RequestOptions?

}
