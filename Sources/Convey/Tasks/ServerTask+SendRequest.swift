//
//  ServerTask+sendRequest.swift
//  
//
//  Created by Ben Gottlieb on 4/29/24.
//

import Foundation

extension ServerTask {
	public func requestResponse() async throws -> ServerResponse {
		if wrappedCaching == .localOnly, self.wrappedTask is ServerCacheableTask {
			if let cache = DataCache.instance.fetchLocal(for: url) {
				return ServerResponse(response: HTTPURLResponse(cachedFor: url, data: cache.data), data: cache.data, fromCache: true, startedAt: cache.cachedAt)
			}
			throw HTTPError.offline
		}
		
		do {
			return try await sendRequest()
		} catch {
			if error.isOffline, self.wrappedTask is ServerCacheableTask {
				return try await requestResponse()
			}
			if error.isOffline, self.wrappedTask is FileBackedTask, let cache = DataCache.instance.fetchLocal(for: url) {
				return ServerResponse(response: HTTPURLResponse(cachedFor: url, data: cache.data), data: cache.data, fromCache: true, startedAt: cache.cachedAt)
			}
			throw error
		}
	}
	
	func sendRequest() async throws -> ServerResponse {
		try await handleThreadAndBackgrounding {
			var attemptCount = 1
			
			if let response = wrappedRedirect?.cached { return response }
			
			while true {
				do {
					let startedAt = Date()
					
					let request = try await beginRequest(at: startedAt)
					let session = ConveySession(task: self.wrappedTask)

					var result = try await session.data(for: request)
					(self.wrappedTask as? ArchivingTask)?.archive(result)
					
					if result.statusCode == 304, let data = DataCache.instance.fetchLocal(for: url), !data.data.isEmpty {
						result.data = data.data
						await server.taskManager.complete(task: self, request: request, response: result.response, bytes: result.data, startedAt: startedAt, usingCache: true)
					} else {
						await server.taskManager.complete(task: self, request: request, response: result.response, bytes: result.data, startedAt: startedAt, usingCache: false)
						if self.wrappedTask is FileBackedTask { self.fileCachedData = result.data }
					}
					
					if self.wrappedTask is ETagCachedTask, let tag = result.response.etag {
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
					
					try await (self.wrappedTask as? PostFlightTask)?.postFlight()
					server.postflight(self, result: result)
					wrappedRedirect?.cache(response: result)
					if wrappedEcho == .timing { logTiming(abs(startedAt.timeIntervalSinceNow)) }
					return result
				} catch {
					if let delay = (self.wrappedTask as? RetryableTask)?.retryInterval(after: error, attemptNumber: attemptCount) {
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

