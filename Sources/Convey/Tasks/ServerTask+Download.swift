//
//  ServerTask+Run.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 10/30/21.
//

import Foundation
import Combine

public extension ServerDownloadConveyable {
	func download() async throws -> DownloadPayload {
		try await downloadWithResponse().payload
	}
	
	func downloadWithResponse() async throws -> PayloadServerResponse<DownloadPayload> {
		try await requestPayload()
	}
}

extension ServerDownloadConveyable {
	@ConveyActor func requestPayload() async throws -> PayloadServerResponse<DownloadPayload> {
		let result = try await requestResponse()
		do {
			let decoded = try decoder.decode(DownloadPayload.self, from: result.data)
			try await postProcess(payload: decoded)
            return PayloadServerResponse(payload: decoded, response: result)
		} catch {
			print("Error when decoding \(DownloadPayload.self) in \(self), \(String(data: result.data, encoding: .utf8) ?? "--unparseable--"): \(error)")
			throw error
		}
	}
}

public extension ServerConveyable where UnderlyingTask: ServerDELETETask {
	@discardableResult func delete() async throws -> ServerResponse {
		try await self.downloadDataWithResponse()
	}
}

public extension ServerConveyable {
	@available(iOS, deprecated: 1, renamed: "downloadDataWithResponse", message: "requestData has been renamed to downloadDataWithResponse()")
	
	func requestData() async throws -> ServerResponse { try await self.downloadDataWithResponse() }

	func downloadData() async throws -> Data {
		try await downloadDataWithResponse().data
	}
	
	func downloadDataWithResponse() async throws -> ServerResponse {
		try await requestResponse()
	}
}
