//
//  ServerTask+sendRequest.swift
//  
//
//  Created by Ben Gottlieb on 4/29/24.
//

import Foundation

extension ServerConveyable {
	@ConveyActor public func requestResponse() async throws -> ServerResponse {
		await willStart()
		await didStart()
		
// #FIXME
//		if wrappedCaching == .localOnly, self.wrappedTask is ServerCacheableTask {
//			if let cache = DataCache.instance.fetchLocal(for: url) {
//				let response = ServerResponse(response: HTTPURLResponse(cachedFor: url, data: cache.data), data: cache.data, fromCache: true, duration: 0, startedAt: cache.cachedAt, retryCount: nil)
//				await willComplete(with: response)
//				await didComplete(with: response)
//				return response
//			}
//			await didFail(with: HTTPError.offline)
//			throw HTTPError.offline
//		}
		
		do {
			return try await sendRequest(sendStart: false)
		} catch {
			if error.isOffline, self.wrappedTask is ServerCacheableTask {
				return try await requestResponse()
			}
			if error.isOffline, self.wrappedTask is FileBackedTask, let cache = DataCache.instance.fetchLocal(for: url) {
				let response = ServerResponse(response: HTTPURLResponse(cachedFor: url, data: cache.data), data: cache.data, fromCache: true, duration: 0, startedAt: cache.cachedAt, retryCount: nil)
				await willComplete(with: response)
				await didComplete(with: response)
				return response
			}
			await didFail(with: error)
			
			throw error
		}
	}
	
	@ConveyActor func sendRequest(sendStart: Bool = true) async throws -> ServerResponse {
		if sendStart {
			await willStart()
			await didStart()
		}
		
		return try await handleThreadAndBackgrounding {
			var attemptCount = 1
//#FIXME
//			if let response = wrappedRedirect?.cached {
//				await willComplete(with: response)
//				await didComplete(with: response)
//				return response
//			}
			
			while true {
				do {
					let startedAt = Date()
					
					let request = try await beginRequest(at: startedAt)
					let session = await ConveySession(task: self.wrappedTask)
					
					var result = try await session.data(for: request)
					(self.wrappedTask as? ArchivingTask)?.archive(result)
					
					if result.statusCode == 304, let data = DataCache.instance.fetchLocal(for: url), !data.data.isEmpty {
						result.data = data.data
						await ConveyTaskReporter.instance.complete(task: self, request: request, response: result.response, bytes: result.data, startedAt: startedAt, usingCache: true)
					} else {
						await ConveyTaskReporter.instance.complete(task: self, request: request, response: result.response, bytes: result.data, startedAt: startedAt, usingCache: false)
						if self.wrappedTask is FileBackedTask { self.fileCachedData = result.data }
					}
					
					if self.wrappedTask is ETagCachedTask, let tag = result.response.etag {
						await DataCache.instance.cache(data: result.data, for: url)
						ETagStore.instance.store(etag: tag, for: url)
					}
					preview?(result)
					try await postProcess(response: result)
					if !result.response.didDownloadSuccessfully {
						server.reportConnectionError(self, result.statusCode, String(data: result.data, encoding: .utf8))
						if result.data.isEmpty || (result.statusCode.isHTTPError && server.configuration.reportBadHTTPStatusAsError) {
							let error = HTTPError.serverError(request.url, result.statusCode, result.data)
							await server.taskFailed(self, error: error)
							await didFail(with: error)
							throw error
						}
					}
					
					try await postFlight()
					server.postflight(self, result: result)
				//	wrappedRedirect?.cache(response: result)
					if echoing == .minimal { logTiming(abs(startedAt.timeIntervalSinceNow)) }
					let retryResult = result.withRetryCount(attemptCount)
					await willComplete(with: retryResult)
					await didComplete(with: retryResult)
					return retryResult
				} catch {
					if let delay = (self.wrappedTask as? RetryableTask)?.retryInterval(after: error, attemptNumber: attemptCount) {
						attemptCount += 1
						try await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
						print("Retry Attempt #\(attemptCount) for \(self)")
					} else {
						await didFail(with: error)
						await server.taskFailed(self, error: error)
						throw error
					}
				}
			}
		}
	}
	
}

