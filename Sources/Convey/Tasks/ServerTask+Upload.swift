//
//  ServerTask+AsyncUpload.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 10/31/21.
//

import Foundation

public extension ServerTask where Self: ServerUploadingTask {
	@discardableResult func uploadOnly() async throws -> Int {
		try await sendRequest().statusCode
	}
}

public extension PayloadDownloadingTask where Self: DataUploadingTask {
	func upload() async throws -> DownloadPayload {
		try await uploadWithResponse().payload
	}

    func uploadWithResponse() async throws -> DownloadResult<DownloadPayload> {
        let result: DownloadResult<DownloadPayload> = try await requestPayload()
        try await postProcess(payload: result.payload)
        return result
	}
}

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
