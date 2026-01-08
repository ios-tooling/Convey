//
//  DownloadingTask+Download.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/19/25.
//

import Foundation

public struct ServerResponse<Payload: Decodable & Sendable>: Sendable {
	public enum ResponseType: Int { case unknown = 0, info = 100, success = 200, redirect = 300, clientError = 400, serverError = 500 }
	
	public let payload: Payload
	public let request: URLRequest
	public let response: URLResponse
	public var httpResponse: HTTPURLResponse? { response as? HTTPURLResponse }
	public var statusCode: Int { httpResponse?.statusCode ?? 0 }
	public let data: Data
	public let startedAt: Date
	public let duration: TimeInterval
	public let attemptNumber: Int
	public let stringResult: String
	
	public var responseType: ResponseType { ResponseType(rawValue: (statusCode / 100) * 100) ?? .unknown }
	
	init(payload: Payload, request: URLRequest, response: URLResponse, data: Data, startedAt: Date, duration: TimeInterval, attemptNumber: Int) {
		self.payload = payload
		self.request = request
		self.response = response
		self.data = data
		self.startedAt = startedAt
		self.duration = duration
		self.attemptNumber = attemptNumber
		self.stringResult = String(data: data, encoding: .utf8) ?? ""
	}

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
		let result = try await performDownload()
		
		if DownloadPayload.self == Data.self, let result = result as? ServerResponse<DownloadPayload>, let payload = result.data as? DownloadPayload {
			await didFinish(with: result)
			return .init(payload: payload, request: result.request, response: result.response, data: result.data, startedAt: result.startedAt, duration: result.duration, attemptNumber: result.attemptNumber)
		}
		
		let decoded: ServerResponse<DownloadPayload> = try result.decoding(using: decoder)
		await didFinish(with: decoded)
		return decoded
	}
	
	func downloadData() async throws -> ServerResponse<Data> {
		let result = try await performDownload()
		
		if DownloadPayload.self == Data.self, let downloadedResult = result as? ServerResponse<DownloadPayload> {
			await didFinish(with: downloadedResult)
		}
		
		return result
	}
	
	func performDownload() async throws -> ServerResponse<Data> {
		let session: ConveySession
		var info = RequestTrackingInfo(self)
		
		if CommandLine.failAllRequests {
			throw FaillAllRequestsError(target: String(describing: type(of: self)))
		}

		do {
			session = try await server.session(for: self)
			defer { session.finish() }
			session.start()
		} catch {
			info.urlRequest = try? await self.request
			info.error = error.localizedDescription
			echo(info, data: nil)
			await didFail(with: error)
			await info.save()

			throw error
		}

		do {
			info.urlRequest = session.request
			let request = session.request
			info.ungzippedRequest = session.ungzippedRequest
			info.url = session.request.url
			info.timeoutDuration = request.timeoutInterval
			
			try await willSendRequest(request: request)
			
			let (data, response, attemptNumber) = try await session.fetchData()
			info.urlResponse = response
			info.data = data
			
			info.duration = abs(info.startedAt.timeIntervalSinceNow)
			info.echoStyle = echoStyle(for: data)
			echo(info, data: data)

			try await didReceiveResponse(response: response, data: data)
			let result = ServerResponse(payload: data, request: session.request, response: response, data: data, startedAt: info.startedAt, duration: info.duration ?? 0, attemptNumber: attemptNumber)
			await info.save()
			await server.didFinish(task: self, response: result, error: nil)
			
			if let error = HTTPError.withStatusCode(result.statusCode, data: result.data, throwingStatusCategories: server.configuration.throwingStatusCategories) {
				throw error
			}
			
			return result
		} catch {
			info.duration = abs(info.startedAt.timeIntervalSinceNow)
			info.error = error.prettyDescription
			info.timedOut = error.isTimeOut
			info.wasCancelled = error.isCancellation
			echo(info, data: nil)

			await didFail(with: error)
			await info.save()
			await server.didFinish(task: self, response: nil, error: error)

			throw error
		}
	}
}

struct FaillAllRequestsError: LocalizedError {
	let target: String
	var errorDescription: String? { "CommandLine.failAllRequests is set to true, so \(target) was not sent." }
}
