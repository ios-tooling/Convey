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

public struct DownloadResult<Payload> {
	public init(payload: Payload, response: ServerReturned) {
		self.payload = payload
		self.response = response
	}
	
	public let payload: Payload
	public let response: ServerReturned
}

@available(macOS 10.15, iOS 13.0, watchOS 7.0, *)
public extension PayloadDownloadingTask {
	func download(caching: DataCache.Caching = .skipLocal, decoder: JSONDecoder? = nil, preview: PreviewClosure? = nil) async throws -> DownloadPayload {
		try await downloadWithResponse().payload
	}
	
	func downloadWithResponse(caching: DataCache.Caching = .skipLocal, decoder: JSONDecoder? = nil, preview: PreviewClosure? = nil) async throws -> DownloadResult<DownloadPayload> {
		let result: DownloadResult<DownloadPayload> = try await requestPayload(caching: caching, decoder: decoder, preview: preview)
		try await postProcess(payload: result.payload)
		return result
	}
}

@available(macOS 10.15, iOS 13.0, watchOS 7.0, *)
public extension ServerTask where Self: ServerDELETETask {
    func delete() async throws {
        _ = try await self.downloadData()
    }
}

@available(macOS 10.15, iOS 13.0, watchOS 7.0, *)
public extension ServerTask {
	func downloadData(caching: DataCache.Caching = .skipLocal, preview: PreviewClosure? = nil) async throws -> Data {
		try await downloadDataWithResponse(caching: caching, preview: preview).data
	}

	func downloadDataWithResponse(caching: DataCache.Caching = .skipLocal, preview: PreviewClosure? = nil) async throws -> ServerReturned {
		try await requestData(caching: caching, preview: preview)
	}
}


@available(macOS 10.15, iOS 13.0, watchOS 7.0, *)
extension ServerTask {
    func requestPayload<Payload: Decodable>(caching: DataCache.Caching = .skipLocal, decoder: JSONDecoder? = nil, preview: PreviewClosure? = nil) async throws -> DownloadResult<Payload> {
		let result = try await requestData(caching: caching, preview: preview)
		let actualDecoder = decoder ?? server.defaultDecoder
        do {
            let decoded = try actualDecoder.decode(Payload.self, from: result.data)
            return DownloadResult(payload: decoded, response: result)
        } catch {
			  print("Error when decoding \(Payload.self) in \(self), \(String(data: result.data, encoding: .utf8) ?? "--unparseable--"): \(error)")
            throw error
        }
	}

	public func requestData(caching: DataCache.Caching = .skipLocal, preview: PreviewClosure? = nil) async throws -> ServerReturned {
		if caching == .localOnly, self is ServerCacheableTask {
			if let data = cachedData {
				return ServerReturned(response: HTTPURLResponse(cachedFor: url, data: data), data: data, fromCache: true)
			}
			throw HTTPError.offline
		}

		do {
			return try await sendRequest(preview: preview)
		} catch {
			if error.isOffline, self is ServerCacheableTask {
				return try await requestData(caching: .skipLocal, preview: preview)
			}
			if error.isOffline, self is FileBackedTask, let data = fileCachedData {
				return ServerReturned(response: HTTPURLResponse(cachedFor: url, data: data), data: data, fromCache: true)
			}
			throw error
		}
	}
	
	#if os(iOS)
		func requestBackgroundTime() -> UIBackgroundTaskIdentifier? {
			server.application?.beginBackgroundTask(withName: "") {  }
		}
		func finishBackgroundTime(_ token: UIBackgroundTaskIdentifier?) {
			guard let token else { return }
			server.application?.endBackgroundTask(token)
		}
	#else
		func requestBackgroundTime() -> Int { 0 }
		func finishBackgroundTime(_ token: Int) { }
	#endif
	
	func handleThreadAndBackgrounding<Result>(closure: () async throws -> Result) async throws -> Result {
		let oneOffLogging = isOneOffLogged

		await server.wait(forThread: (self as? ThreadedServerTask)?.threadName)
		let token = requestBackgroundTime()
		let result = try await closure()
		finishBackgroundTime(token)
		await server.stopWaiting(forThread: (self as? ThreadedServerTask)?.threadName)
		if oneOffLogging { ConveyTaskManager.instance.decrementOneOffLog(for: self) }
		return result
	}
	
	func sendRequest(preview: PreviewClosure? = nil) async throws -> ServerReturned {
		try await handleThreadAndBackgrounding {
			var attemptCount = 1
			
			while true {
				do {
					let startedAt = Date()
					
					let request = try await beginRequest(at: startedAt)
					let session = ConveySession(task: self)
					var result = try await session.data(for: request)
					
					if result.statusCode == 304, let data = DataCache.instance.fetchLocal(for: url), !data.data.isEmpty {
						result.data = data.data
						await ConveyTaskManager.instance.complete(task: self, request: request, response: result.response, bytes: result.data, startedAt: startedAt, usingCache: true)
					} else {
						await ConveyTaskManager.instance.complete(task: self, request: request, response: result.response, bytes: result.data, startedAt: startedAt, usingCache: false)
						if self is FileBackedTask { self.fileCachedData = result.data }
					}
					
					if self is ETagCachedTask, let tag = result.response.etag {
						DataCache.instance.cache(data: result.data, for: url)
						ETagStore.instance.store(etag: tag, for: url)
					}
					preview?(result)
					try await postProcess(response: result)
					if !result.response.didDownloadSuccessfully {
						server.reportConnectionError(self, result.statusCode, String(data: result.data, encoding: .utf8))
						if result.data.isEmpty || (result.statusCode.isHTTPError && server.reportBadHTTPStatusAsError) {
							throw HTTPError.serverError(request.url, result.statusCode, result.data)
						}
					}
					
					try await (self as? PostFlightTask)?.postFlight()
					return result
				} catch {
					if let delay = (self as? RetryableTask)?.retryInterval(after: error, attemptNumber: attemptCount) {
						attemptCount += 1
						try await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
					} else {
						throw error
					}
				}
			}
		}
	}

}
