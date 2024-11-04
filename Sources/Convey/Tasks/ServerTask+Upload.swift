//
//  ServerTask+AsyncUpload.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 10/31/21.
//

import Foundation

public extension ServerTask where Self: ServerUploadingTask {
	@discardableResult func uploadOnly() async throws -> Int { try await sendRequest().statusCode }
	func upload() async throws -> Int { try await sendRequest().statusCode }
	func uploadAndDownload() async throws -> Data { try await sendRequest().data }
	func uploadAndDownloadData() async throws -> Data { try await sendRequest().data }
	func uploadWithResponse() async throws -> ServerResponse { try await sendRequest() }

}

public extension WrappedServerTask where Wrapped: ServerUploadingTask {
	@discardableResult func uploadOnly() async throws -> Int { try await sendRequest().statusCode }
	func upload() async throws -> Int { try await sendRequest().statusCode }
	func uploadAndDownload() async throws -> Data { try await sendRequest().data }
	func uploadAndDownloadData() async throws -> Data { try await sendRequest().data }
	func uploadWithResponse() async throws -> ServerResponse { try await sendRequest() }
}

public extension PayloadDownloadingTask where Self: DataUploadingTask {
	func upload() async throws -> DownloadPayload {
		try await uploadWithResponse().payload
	}

	 func uploadWithResponse() async throws -> PayloadServerResponse<DownloadPayload> {
		  let result: PayloadServerResponse<DownloadPayload> = try await requestPayload()
		  try await postProcess(payload: result.payload)
		  return result
	}
}

public extension WrappedPayloadDownloadingTask where Wrapped: DataUploadingTask {
	func upload() async throws -> DownloadPayload {
		try await uploadWithResponse().payload
	}

	 func uploadWithResponse() async throws -> PayloadServerResponse<DownloadPayload> {
		  let result: PayloadServerResponse<DownloadPayload> = try await requestPayload()
		  try await postProcess(payload: result.payload)
		  return result
	}
}
