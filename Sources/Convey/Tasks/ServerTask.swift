//
//  ServerTask.swift
//  ServerTask
//
//  Created by Ben Gottlieb on 9/11/21.
//

import Foundation

public typealias PreviewClosure = @Sendable (ServerResponse) -> Void

@ConveyActor public protocol ServerTask: ServerConveyable where UnderlyingTask == Self {
}



public extension ServerTask {
	var wrappedTask: Self { self }
	var caching: DataCache.Caching { .skipLocal }
	var customURL: URL? { nil }
	var preview: PreviewClosure? { nil }

	func willStart() async { }
	func didStart() async { }
	
	func willComplete(with: ServerResponse) async { }
	func didComplete(with: ServerResponse) async { }
	
	func didFail(with error: Error) async { }
	var timeout: TimeInterval { get async { server.configuration.defaultTimeout }}
	var cookies: [HTTPCookie]? { nil }
	
	func preFlight() async throws { }
	func postFlight() async throws { }
	var encoder: JSONEncoder { server.configuration.defaultEncoder }
	var decoder: JSONDecoder { server.configuration.defaultDecoder }
	var headers: ConveyHeaders { [String: String]() }
	var parameters: TaskURLParameters? { nil }
	var reportBadHTTPStatusAsError: Bool { server.configuration.reportBadHTTPStatusAsError }
	var echoing: ConveyEchoStyle? { (self is any EchoingTask) ? .always : nil }
	var requestOptions: RequestOptions? { nil }
	
	func add(echoing: ConveyEchoStyle? = nil, timeout: TimeInterval? = nil, caching: DataCache.Caching? = nil, headers: ConveyHeaders? = nil, parameters: TaskURLParameters? = nil, reportBadHTTPStatusAsError: Bool? = nil, encoder: JSONEncoder? = nil, decoder: JSONDecoder? = nil, willStart: (() -> Void)? = nil, didComplete: ((ServerResponse) -> Void)? = nil, requestOptions: RequestOptions? = nil) -> ServerTaskContainer<Self> {
		var copy = ServerTaskContainer(root: self)
		
		if let echoing { copy.echoingOverride = echoing }
		if let timeout { copy.timeoutOverride = timeout }
		if let caching { copy.cachingOverride = caching }
		if let headers { copy.additionalHeaders = headers }
		if let parameters { copy.additionalParameters = parameters }
		if let encoder { copy.overrideEncoder = encoder }
		if let decoder { copy.overrideDecoder = decoder }
		if let willStart { copy.extraWillStart = willStart }
		if let didComplete { copy.extraDidComplete = didComplete }
		if let requestOptions { copy.requestOptionsOverride = requestOptions }
		
		return copy
	}

}

extension ServerTask {
	public func echo(_ echoing: ConveyEchoStyle? = .always) -> ServerTaskContainer<Self> { add(echoing: echoing) }
	public func timeout(_ timeout: TimeInterval?) -> ServerTaskContainer<Self> { add(timeout: timeout) }
	public func caching(_ caching: DataCache.Caching?) -> ServerTaskContainer<Self> { add(caching: caching) }
	public func headers(_ headers: ConveyHeaders?) -> ServerTaskContainer<Self> { add(headers: headers) }
	public func parameters(_ parameters: TaskURLParameters?) -> ServerTaskContainer<Self> { add(parameters: parameters) }
	public func reportBadHTTPStatusAsError(_ report: Bool? = true) -> ServerTaskContainer<Self> { add(reportBadHTTPStatusAsError: report) }
	public func encoder(_ encoder: JSONEncoder?) -> ServerTaskContainer<Self> { add(encoder: encoder) }
	public func decoder(_ decoder: JSONDecoder?) -> ServerTaskContainer<Self> { add(decoder: decoder) }
	public func didComplete(_ didComplete: ((ServerResponse) -> Void)?) -> ServerTaskContainer<Self> { add(didComplete: didComplete) }
	public func willStart(_ willStart: (() -> Void)?) -> ServerTaskContainer<Self> { add(willStart: willStart) }
	public func addRequestOptions(_ options: RequestOptions?) -> ServerTaskContainer<Self> { add(requestOptions: options) }
	public func addSourceURL(_ url: URL) -> ServerTaskContainer<Self> {
		var opts = requestOptions ?? RequestOptions()
		opts.sourceFileURL = url
		return add(requestOptions: opts)
	}
}
