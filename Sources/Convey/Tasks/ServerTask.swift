//
//  ServerTask.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/19/25.
//

import Foundation

public typealias ServerTask = DataDownloadingTask

@ConveyActor public protocol DownloadingTask<DownloadPayload>: Sendable {
	associatedtype DownloadPayload: Decodable & Sendable
	
	var configuration: TaskConfiguration { get async }
	var path: String { get async }
	var url: URL { get async }
	var request: URLRequest { get async throws }
	var method: HTTPMethod { get }
	var decoder: JSONDecoder { get }
	var allowsConstrainedNetworkAccess: Bool? { get }
	var allowsExpensiveNetworkAccess: Bool? { get }
	var timeoutIntervalForRequest: TimeInterval? { get }
	var timeoutIntervalForResource: TimeInterval? { get }
	var retryCount: Int { get }
	var headers: Headers { get async }
	var queryParameters: (any TaskQueryParameters)? { get async }
	var requestTag: String? { get }

	func willSendRequest(request: URLRequest) async throws
	func didReceiveResponse(response: HTTPURLResponse, data: Data) async throws
}

public protocol DataDownloadingTask: DownloadingTask where DownloadPayload == Data { }
public protocol ResultIgnoredTask: DownloadingTask where DownloadPayload == Data { }

public protocol UploadingTask<UploadPayload>: DownloadingTask {
	associatedtype UploadPayload: Encodable & Sendable
	var uploadPayload: UploadPayload? { get }
	var uploadData: Data? { get async throws }
	var encoder: JSONEncoder { get }
	var gzip: Bool { get }
	var contentType: String? { get }
}

public protocol DataUploadingTask: UploadingTask {
	typealias UploadPayload = Data
	typealias DownloadPayload = Data
}

public extension DownloadingTask {
	var server: ConveyServerable { ConveyServer.default }
	var configuration: TaskConfiguration { server.defaultTaskConfiguration }
	var url: URL { URL(string: "")! }
	var method: HTTPMethod { .get }
	var path: String { "" }
	var decoder: JSONDecoder { server.defaultDecoder }
	var allowsConstrainedNetworkAccess: Bool? { nil }
	var allowsExpensiveNetworkAccess: Bool? { nil }
	var timeoutIntervalForRequest: TimeInterval? { server.configuration.defaultTimeout }
	var timeoutIntervalForResource: TimeInterval? { nil }
	var retryCount: Int { 0 }
	var headers: Headers { get async { await server.headers(for: self) }}
	var queryParameters: (any TaskQueryParameters)? { nil }
	var requestTag: String? { nil }

	func willSendRequest(request: URLRequest) async throws { }
	func didReceiveResponse(response: HTTPURLResponse, data: Data) async throws { }
}
