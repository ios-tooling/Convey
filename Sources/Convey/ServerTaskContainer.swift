//
//  ServerTaskContainer.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 11/23/24.
//

import Foundation

@ConveyActor public struct ServerTaskContainer<RootTask: ServerTask> {
	let root: RootTask
	
	init(root: RootTask) {
		self.root = root
	}
	
	var customURL: URL? { get async { root.customURL }}
	var caching: DataCache.Caching { root.caching }
	var wrappedTask: any ServerTask { root }
	var path: String { root.path }
	func postProcess(response: ServerResponse) async throws { try await root.postProcess(response: response) }
	var httpMethod: String { root.httpMethod }
	var server: ConveyServer { root.server }
	var url: URL { root.url }
	var taskTag: String { root.taskTag }
	var timeout: TimeInterval { get async { await root.timeout } }

	func willStart() async { await root.willStart() }
	func didStart() async { await root.didStart() }
	func preFlight() async throws { try await root.preFlight() }
	func postFlight() async throws { try await root.postFlight() }

	func willComplete(with: ServerResponse) async { await root.willComplete(with: with) }
	func didComplete(with: ServerResponse) async { await root.didComplete(with: with) }
	var headers: ConveyHeaders { root.headers }
	var parameters: TaskURLParameters? { root.parameters }

	func didFail(with error: Error) async { await root.didFail(with: error) }
	
	func buildRequest() async throws -> URLRequest { try await root.buildRequest() }
	var cookies: [HTTPCookie]? { root.cookies }
	var encoder: JSONEncoder? { root.encoder }
	var decoder: JSONDecoder? { root.decoder }
	var reportBadHTTPStatusAsError: Bool { root.reportBadHTTPStatusAsError }
	var echoing: ConveyEchoStyle? { root.echoing }
}
