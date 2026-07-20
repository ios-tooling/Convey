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
	func send(file: String = #file, function: String = #function, line: Int = #line) async throws {
		if !server.isSetup { return }
		let _ = try await download(usingRecordedTaskID: nil, file: file, function: function, line: line)
	}

	func download(file: String = #file, function: String = #function, line: Int = #line) async throws -> ServerResponse<DownloadPayload> {
		try await download(usingRecordedTaskID: nil, file: file, function: function, line: line)
	}
	
	func downloadData(file: String = #file, function: String = #function, line: Int = #line) async throws -> ServerResponse<Data> {
		try await downloadData(usingRecordedTaskID: nil, file: file, function: function, line: line)
	}
}

extension DownloadingTask {
	func download(usingRecordedTaskID id: String?, file: String = #file, function: String = #function, line: Int = #line) async throws -> ServerResponse<DownloadPayload> {
		let result: ServerResponse<DownloadPayload> = try await performDownload(
			usingRecordedTaskID: id,
			file: file,
			function: function,
			line: line
		) { raw in
			if DownloadPayload.self == Data.self, let payload = raw.data as? DownloadPayload {
				return .init(payload: payload, request: raw.request, response: raw.response, data: raw.data, startedAt: raw.startedAt, duration: raw.duration, attemptNumber: raw.attemptNumber)
			}
			return try raw.decoding(using: decoder)
		}
		await didFinish(with: result)
		if #available(iOS 17, macOS 14, watchOS 10, *) {
			await TaskObserver.instance.didComplete(self, payload: result.payload)
		}
		return result
	}
	
	func downloadData(usingRecordedTaskID id: String?, file: String = #file, function: String = #function, line: Int = #line) async throws -> ServerResponse<Data> {
		let result: ServerResponse<Data> = try await performDownload(usingRecordedTaskID: id, file: file, function: function, line: line) { $0 }
		
		if DownloadPayload.self == Data.self, let downloadedResult = result as? ServerResponse<DownloadPayload> {
			await didFinish(with: downloadedResult)
			if #available(iOS 17, macOS 14, watchOS 10, *), let payload = result.data as? DownloadPayload {
				await TaskObserver.instance.didComplete(self, payload: payload)
			}
		}
		
		return result
	}
	
	func performDownload<Payload: Decodable & Sendable>(
		usingRecordedTaskID id: String?,
		file: String = #file,
		function: String = #function,
		line: Int = #line,
		transform: (ServerResponse<Data>) throws -> ServerResponse<Payload>
	) async throws -> ServerResponse<Payload> {
		var info = TaskRecordingInfo(self, id: id)
		var responseData: Data?

		do {
			if CommandLine.failAllRequests {
				throw FaillAllRequestsError(target: String(describing: type(of: self)))
			}
			let session = try await server.session(for: self)
			session.start()
			defer { session.finish() }
			session.request = try await willSendRequest(session.request)

			info.urlRequest = session.request
			let request = session.request
			info.ungzippedRequest = session.ungzippedRequest
			info.record(url: session.request.url)
			info.timeoutDuration = request.timeoutInterval

			let (data, response, attemptNumber, error) = try await session.fetchData()
			responseData = data
			info.urlResponse = response
			info.record(responseData: data)
			
			info.duration = abs(info.startedAt.timeIntervalSinceNow)
			info.echoStyle = echoStyle(for: data)
			echo(info, data: data)
			if let error { throw error }
			try await didReceiveResponse(response: response, data: data)
			let raw = ServerResponse(payload: data, request: session.request, response: response, data: data, startedAt: info.startedAt, duration: info.duration ?? 0, attemptNumber: attemptNumber)
			let result = try transform(raw)
			info.isComplete = true
			await info.save(file: file, function: function, line: line)
			await server.didFinish(task: self, response: raw, error: nil)
			return result
		} catch {
			if info.url == nil { info.record(url: await self.url) }
			info.duration = abs(info.startedAt.timeIntervalSinceNow)
			info.record(error: error)
			info.wasCancelled = error.isCancellation
			info.timedOut = error.isTimeOut
			if server.configuration.logCancelledTasks || !info.wasCancelled { echo(info, data: nil) }
			var thrownError = error
			
			if let statusCode = info.response?.statusCode {
				if let newError = HTTPError.withStatusCode(statusCode, data: responseData, throwingStatusCategories: throwingStatusCategories, underlyingError: error) {	thrownError = newError }
				let statusFamily = (statusCode / 100) * 100
				if !server.configuration.incompleteCategories.contains(statusFamily) { info.isComplete = true }
			}

			await didFail(with: thrownError)
			if server.configuration.logCancelledTasks || !info.wasCancelled {
				await info.save(file: file, function: function, line:line)
			}
			await server.didFinish(task: self, response: nil, error: thrownError)
			if #available(iOS 17, macOS 14, watchOS 10, *) {
				await TaskObserver.instance.didFail(self, with: thrownError)
			}

			throw thrownError
		}
	}
}

struct FaillAllRequestsError: LocalizedError {
	let target: String
	var errorDescription: String? { "CommandLine.failAllRequests is set to true, so \(target) was not sent." }
}
