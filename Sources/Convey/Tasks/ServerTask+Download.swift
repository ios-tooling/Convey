//
//  ServerTask+Run.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 10/30/21.
//

import Foundation
import Combine

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
		let actualDecoder = wrappedDecoder ?? server.configuration.defaultDecoder
		do {
			let decoded = try actualDecoder.decode(DownloadPayload.self, from: result.data)
			try await postProcess(payload: decoded)
            return DownloadResult(payload: decoded, response: result, retryCount: result.retryCount, duration:  result.duration)
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
