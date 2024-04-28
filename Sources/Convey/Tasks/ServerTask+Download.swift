//
//  ServerTask+Run.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 10/30/21.
//

import Foundation
import Combine

#if os(iOS)
import UIKit
#endif

public extension PayloadDownloadingTask {
	func download() async throws -> DownloadPayload {
		try await downloadPayloadWithResponse().payload
	}
	
	func downloadPayload() async throws -> DownloadPayload {
		try await downloadPayloadWithResponse().payload
	}
	
	func downloadPayloadWithResponse() async throws -> DownloadResult<DownloadPayload> {
		try await requestPayload()
	}
}

extension PayloadDownloadingTask {
	func requestPayload() async throws -> DownloadResult<DownloadPayload> {
		let result = try await requestResponse()
		let actualDecoder = wrappedDecoder ?? server.defaultDecoder
		do {
			let decoded = try actualDecoder.decode(DownloadPayload.self, from: result.data)
			try await postProcess(payload: decoded)
			return DownloadResult(payload: decoded, response: result)
		} catch {
			print("Error when decoding \(DownloadPayload.self) in \(self), \(String(data: result.data, encoding: .utf8) ?? "--unparseable--"): \(error)")
			throw error
		}
	}
}

public extension ServerTask where Self: ServerDELETETask {
	@discardableResult func delete() async throws -> ServerResponse {
		try await self.downloadDataWithResponse()
	}
}

public extension WrappedServerTask where Wrapped: ServerDELETETask {
	@discardableResult func delete() async throws -> ServerResponse {
		try await self.downloadDataWithResponse()
	}
}

public extension ServerTask {
	@available(iOS, deprecated: 1, renamed: "downloadDataWithResponse", message: "requestData has been renamed to downloadDataWithResponse()")
	func requestData(caching: DataCache.Caching = .skipLocal) async throws -> ServerResponse { try await self.caching(caching).downloadDataWithResponse() }

	func downloadData() async throws -> Data {
		try await downloadDataWithResponse().data
	}
	
	func downloadDataWithResponse() async throws -> ServerResponse {
		try await requestResponse()
	}
}


extension ServerTask {
	public func requestResponse() async throws -> ServerResponse {
		if wrappedCaching == .localOnly, self is ServerCacheableTask {
			if let cache = DataCache.instance.fetchLocal(for: url) {
				return ServerResponse(response: HTTPURLResponse(cachedFor: url, data: cache.data), data: cache.data, fromCache: true, startedAt: cache.cachedAt)
			}
			throw HTTPError.offline
		}
		
		do {
			return try await sendRequest()
		} catch {
			if error.isOffline, self is ServerCacheableTask {
				return try await requestResponse()
			}
			if error.isOffline, self is FileBackedTask, let cache = DataCache.instance.fetchLocal(for: url) {
				return ServerResponse(response: HTTPURLResponse(cachedFor: url, data: cache.data), data: cache.data, fromCache: true, startedAt: cache.cachedAt)
			}
			throw error
		}
	}
	
#if os(iOS)
	@MainActor func requestBackgroundTime() async -> UIBackgroundTaskIdentifier? {
		server.application?.beginBackgroundTask(withName: "") {  }
	}
	@MainActor func finishBackgroundTime(_ token: UIBackgroundTaskIdentifier?) {
		guard let token else { return }
		server.application?.endBackgroundTask(token)
	}
#else
	func requestBackgroundTime() async -> Int { 0 }
	func finishBackgroundTime(_ token: Int) async { }
#endif
	
	func handleThreadAndBackgrounding<Result: Sendable>(closure: () async throws -> Result) async throws -> Result {
		let oneOffLogging = await isOneOffLogged
		
		await server.wait(forThread: (self as? ThreadedServerTask)?.threadName)
		let token = await requestBackgroundTime()
		let result = try await closure()
		await finishBackgroundTime(token)
		await server.stopWaiting(forThread: (self as? ThreadedServerTask)?.threadName)
		if oneOffLogging { await server.taskManager.decrementOneOffLog(for: self) }
		return result
	}
	
	func sendRequest() async throws -> ServerResponse {
		try await handleThreadAndBackgrounding {
			var attemptCount = 1
			
			while true {
				do {
					let startedAt = Date()
					
					let request = try await beginRequest(at: startedAt)
					let session = ConveySession(task: self)
					var result = try await session.data(for: request)
					(self as? ArchivingTask)?.archive(result)
					
					if result.statusCode == 304, let data = DataCache.instance.fetchLocal(for: url), !data.data.isEmpty {
						result.data = data.data
						await server.taskManager.complete(task: self, request: request, response: result.response, bytes: result.data, startedAt: startedAt, usingCache: true)
					} else {
						await server.taskManager.complete(task: self, request: request, response: result.response, bytes: result.data, startedAt: startedAt, usingCache: false)
						if self is FileBackedTask { self.fileCachedData = result.data }
					}
					
					if self is ETagCachedTask, let tag = result.response.etag {
						await DataCache.instance.cache(data: result.data, for: url)
						await ETagStore.instance.store(etag: tag, for: url)
					}
					wrappedPreview?(result)
					try await postProcess(response: result)
					if !result.response.didDownloadSuccessfully {
						server.reportConnectionError(self, result.statusCode, String(data: result.data, encoding: .utf8))
						if result.data.isEmpty || (result.statusCode.isHTTPError && server.reportBadHTTPStatusAsError) {
							let error = HTTPError.serverError(request.url, result.statusCode, result.data)
							server.taskFailed(self, error: error)
							throw error
						}
					}
					
					try await (self as? PostFlightTask)?.postFlight()
					server.postflight(self, result: result)
					return result
				} catch {
					if let delay = (self as? RetryableTask)?.retryInterval(after: error, attemptNumber: attemptCount) {
						attemptCount += 1
						try await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
					} else {
						server.taskFailed(self, error: error)
						throw error
					}
				}
			}
		}
	}
	
}
