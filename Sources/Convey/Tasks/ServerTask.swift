//
//  ServerTask.swift
//  ServerTask
//
//  Created by Ben Gottlieb on 9/11/21.
//

import Foundation

public typealias PreviewClosure = @Sendable (ServerResponse) -> Void

public protocol ServerTask: Sendable {
	var path: String { get }
	func postProcess(response: ServerResponse) async throws
	var httpMethod: String { get }
	var server: ConveyServer { get }
	var url: URL { get }
	var taskTag: String { get }
	var timeout: TimeInterval { get }

	func willStart() async
	func didStart() async
	
	func willComplete(with: ServerResponse) async
	func didComplete(with: ServerResponse) async
	
	func didFail(with error: Error) async
}

public extension ServerTask {
	func willStart() async { }
	func didStart() async { }
	
	func willComplete(with: ServerResponse) async { }
	func didComplete(with: ServerResponse) async { }
	
	func didFail(with error: Error) async { }
	var timeout: TimeInterval { server.defaultTimeout }
}
