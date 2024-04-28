//
//  ServerTask+AsyncUpload.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 10/31/21.
//

import Foundation

@available(macOS 10.15, iOS 13.0, watchOS 7.0, *)
public extension ServerTask where Self: ServerUploadingTask {
	func uploadOnly() async throws {
		_ = try await sendRequest()
	}
}

@available(macOS 10.15, iOS 13.0, watchOS 7.0, *)
public extension PayloadDownloadingTask where Self: DataUploadingTask {
	func upload() async throws -> DownloadPayload {
		try await uploadWithResponse().payload
	}

    func uploadWithResponse() async throws -> DownloadResponse<DownloadPayload> {
        let result: DownloadResponse<DownloadPayload> = try await requestPayload()
        try await postProcess(payload: result.payload)
        return result
	}
}

@available(macOS 10.15, iOS 13.0, watchOS 7.0, *)
public extension DataUploadingTask {
	func uploadAndDownload() async throws -> Data {
		try await sendRequest().data
	}

	func upload() async throws -> Int {
		try await sendRequest().response.statusCode
	}

	func uploadWithResponse() async throws -> URLResponse {
		try await sendRequest().response
	}
}
