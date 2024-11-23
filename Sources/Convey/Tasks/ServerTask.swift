//
//  ServerTask.swift
//  ServerTask
//
//  Created by Ben Gottlieb on 9/11/21.
//

import Foundation

public typealias PreviewClosure = @Sendable (ServerResponse) -> Void

@ConveyActor public protocol ServerTask: ServerConveyable {
}



public extension ServerTask {
	var wrappedTask: any ServerTask { self }
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
	var encoder: JSONEncoder? { nil }
	var decoder: JSONDecoder? { nil }
	var headers: ConveyHeaders { [String: String]() }
	var parameters: TaskURLParameters? { nil }
	var reportBadHTTPStatusAsError: Bool { server.configuration.reportBadHTTPStatusAsError }
	var echoing: ConveyEchoStyle? { nil }
}
