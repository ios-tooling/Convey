//
//  ServerConveyable.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 11/23/24.
//

import Foundation

public enum ConveyEchoStyle: Sendable { case dontEcho, minimal, full, always }

@ConveyActor public protocol ServerConveyable: Sendable {
	associatedtype UnderlyingTask: ServerTask
	var wrappedTask: UnderlyingTask { get }
	var path: String { get }
	var httpMethod: String { get }
	var server: ConveyServer { get }
	var url: URL { get }
	var taskTag: String { get }
	var timeout: TimeInterval { get async }
	var caching: DataCache.Caching { get }
	var customURL: URL? { get }
	var preview: PreviewClosure? { get }

	func willStart() async
	func didStart() async
	func preFlight() async throws
	func postFlight() async throws
	func postProcess(response: ServerResponse) async throws

	func willComplete(with: ServerResponse) async
	func didComplete(with: ServerResponse) async
	var headers: ConveyHeaders { get }
	var parameters: TaskURLParameters? { get }

	func didFail(with error: Error) async
	
	func buildRequest() async throws -> URLRequest
	var cookies: [HTTPCookie]? { get }
	var encoder: JSONEncoder { get }
	var decoder: JSONDecoder { get }
	var reportBadHTTPStatusAsError: Bool { get }
	var echoing: ConveyEchoStyle? { get }
	var requestOptions: RequestOptions? { get }
}


public protocol ServerPayloadDownloadConveyable<DownloadPayload>: ServerConveyable {
	associatedtype DownloadPayload: Decodable & Sendable
	func postProcess(payload: DownloadPayload) async throws
}

public protocol ServerUploadConveyable: ServerConveyable {}

public protocol ServerPayloadUploadConveyable: ServerConveyable {
	associatedtype UploadPayload: Encodable & Sendable
	var uploadPayload: UploadPayload? { get }
}
