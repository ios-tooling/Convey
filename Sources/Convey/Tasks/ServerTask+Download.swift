//
//  File.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/19/25.
//

import Foundation

public struct ServerResponse<Payload: Decodable & Sendable>: Sendable {
	public let payload: Payload
	public let request: URLRequest
	public let response: URLResponse
	public var httpResponse: HTTPURLResponse? { response as? HTTPURLResponse }
	public var statusCode: Int { httpResponse?.statusCode ?? 0 }
	public let data: Data
	public let startedAt: Date
	public let duration: TimeInterval
	public let attemptNumber: Int

	public func decoding<T: Decodable & Sendable>(using decoder: JSONDecoder) throws -> ServerResponse<T> {
		
		let payload = try decoder.decode(T.self, from: data)
		return .init(payload: payload, request: request, response: response, data: data, startedAt: startedAt, duration: duration, attemptNumber: attemptNumber)
	}
}

public extension DownloadingTask {
	func send() async throws {
		let _ = try await download()
	}

	func download() async throws -> ServerResponse<DownloadPayload> {
		let result = try await downloadData()
		
		if DownloadPayload.self == Data.self {
			return .init(payload: result.data as! DownloadPayload, request: result.request, response: result.response, data: result.data, startedAt: result.startedAt, duration: result.duration, attemptNumber: result.attemptNumber)
		}
		
		let decoded: ServerResponse<DownloadPayload> = try result.decoding(using: decoder)
		return decoded
	}
	
	func downloadData() async throws -> ServerResponse<Data> {
		let session = try await server.session(for: self)
		var info = RequestTrackingInfo(self)

		do {
			info.urlRequest = session.request
			
			try await willSendRequest(request: request)
			
			let (data, response, attemptNumber) = try await session.fetchData()
			info.urlResponse = response
			info.data = data
			
			info.duration = abs(info.startedAt.timeIntervalSinceNow)
			echo(info)

			try await didReceiveResponse(response: response, data: data)
			let result = ServerResponse(payload: data, request: session.request, response: response, data: data, startedAt: info.startedAt, duration: info.duration!, attemptNumber: attemptNumber)
			session.finish()
			return result
		} catch {
			info.duration = abs(info.startedAt.timeIntervalSinceNow)
			info.error = error.localizedDescription
			echo(info)
			await didFail(with: error)
			session.finish()
			throw error
		}
	}
}
