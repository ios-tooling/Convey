//
//  DownloadingTask.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/19/25.
//

import Foundation

public typealias ServerTask = DataDownloadingTask

@ConveyActor public protocol DownloadingTask<DownloadPayload>: Sendable {
	associatedtype DownloadPayload: Decodable & Sendable
	
	var configuration: TaskConfiguration? { get set }
	var path: String { get async }
	var url: URL { get async }
	var request: URLRequest { get async throws }
	var method: HTTPMethod { get }
	var decoder: JSONDecoder { get }
	var allowsConstrainedNetworkAccess: Bool? { get }
	var allowsExpensiveNetworkAccess: Bool? { get }
	var timeoutIntervalForRequest: TimeInterval? { get }
	var timeoutIntervalForResource: TimeInterval? { get }
	var headers: Headers { get async throws }
	var queryParameters: (any TaskQueryParameters)? { get async }
	var requestTag: String? { get }
	var server: ConveyServerable { get }
	func retryInterval(afterCount: Int) -> TimeInterval?

	func willSendRequest(request: URLRequest) async throws
	func didReceiveResponse(response: URLResponse, data: Data) async throws
	func didFail(with error: any Error) async
}

public protocol DataDownloadingTask: DownloadingTask where DownloadPayload == Data { }
public protocol IgnoredResultsTask: DownloadingTask where DownloadPayload == Data { }

public protocol UploadingTask<UploadPayload>: DownloadingTask {
	associatedtype UploadPayload: Encodable & Sendable
	var uploadPayload: UploadPayload? { get }
	var uploadData: Data? { get async throws }
	var encoder: JSONEncoder { get }
	var gzip: Bool { get }
	var contentType: String? { get }
}

public protocol DataUploadingTask: UploadingTask where UploadPayload == Data, DownloadPayload == Data {
}

public extension DownloadingTask {
	var server: ConveyServerable { ConveyServer.default }
	var configuration: TaskConfiguration { server.defaultTaskConfiguration }
	var url: URL { get async { await server.url(for: self) }}
	var method: HTTPMethod { .get }
	var path: String { "" }
	var decoder: JSONDecoder { server.defaultDecoder }
	var allowsConstrainedNetworkAccess: Bool? { nil }
	var allowsExpensiveNetworkAccess: Bool? { nil }
	var timeoutIntervalForRequest: TimeInterval? { server.configuration.defaultTimeout }
	var timeoutIntervalForResource: TimeInterval? { nil }
	var headers: Headers { get async throws { try await server.headers(for: self) }}
	var queryParameters: (any TaskQueryParameters)? { nil }
	var requestTag: String? { nil }
	func retryInterval(afterCount: Int) -> TimeInterval? { nil }

	func willSendRequest(request: URLRequest) async throws { }
	func didReceiveResponse(response: URLResponse, data: Data) async throws { }
	func didFail(with error: any Error) async { }
}
