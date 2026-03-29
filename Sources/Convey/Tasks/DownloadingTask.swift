//
//  DownloadingTask.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/19/25.
//

import Foundation
import TagAlong

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
	var requestID: String? { get }
	var server: ConveyServerable { get }
	var acceptType: String { get }
	var throwingStatusCategories: [Int] { get }
	func retryInterval(afterError error: any Error, count: Int) -> TimeInterval?

	func willSendRequest(request: URLRequest) async throws
	func didReceiveResponse(response: URLResponse, data: Data) async throws
	func didFail(with error: any Error) async
	func didFinish(with response: ServerResponse<DownloadPayload>) async
	var echoStyle: TaskEchoStyle { get }
	func echoStyle(for data: Data?) -> TaskEchoStyle
	var tags: TagCollection? { get }
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
	var url: URL { get async { await server.url(for: self) }}
	var method: HTTPMethod { .get }
	var path: String { "" }
	var decoder: JSONDecoder { server.defaultDecoder }
	var allowsConstrainedNetworkAccess: Bool? { nil }
	var allowsExpensiveNetworkAccess: Bool? { nil }
	var timeoutIntervalForRequest: TimeInterval? { server.configuration.defaultTimeout }
	var timeoutIntervalForResource: TimeInterval? { nil }
	var headers: Headers { get async throws { [] }}
	var queryParameters: (any TaskQueryParameters)? { nil }
	var requestID: String? { nil }
	var tags: TagCollection? { nil }
	func retryInterval(afterError error: any Error, count: Int) -> TimeInterval? { nil }
	var throwingStatusCategories: [Int] { configuration?.throwingStatusCategories ?? server.configuration.throwingStatusCategories }
	
	func willSendRequest(request: URLRequest) async throws { }
	func didReceiveResponse(response: URLResponse, data: Data) async throws { }
	func didFail(with error: any Error) async { }
	func didFinish(with response: ServerResponse<DownloadPayload>) async { }
	
	var acceptType: String { "*/*" }
	var allTags: [Tag]? {
		let all = (tags?.tags ?? []) + (configuration?.tags?.tags ?? [])
		return all.isEmpty ? nil : all
	}
}
