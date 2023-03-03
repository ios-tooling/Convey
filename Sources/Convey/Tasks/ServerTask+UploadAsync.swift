//
//  ServerTask+AsyncUpload.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 10/31/21.
//

import Foundation

@available(macOS 10.15, iOS 13.0, watchOS 7.0, *)
public extension PayloadDownloadingTask where Self: DataUploadingTask {
	func upload(decoder: JSONDecoder? = nil, preview: PreviewClosure? = nil) async throws -> DownloadPayload {
		try await uploadWithResponse(decoder: decoder, preview: preview).payload
	}

    func uploadWithResponse(decoder: JSONDecoder? = nil, preview: PreviewClosure? = nil) async throws -> DownloadResult<DownloadPayload> {
        let result: DownloadResult<DownloadPayload> = try await requestPayload(caching: .skipLocal, decoder: decoder, preview: preview)
        try await postProcess(payload: result.payload)
        return result
	}
}

@available(macOS 10.15, iOS 13.0, watchOS 7.0, *)
public extension DataUploadingTask {
	func uploadAndDownload(preview: PreviewClosure? = nil) async throws -> Data {
		try await sendRequest(preview: preview).data
	}

	func upload(preview: PreviewClosure? = nil) async throws -> Int {
		try await sendRequest(preview: preview).response.statusCode
	}

	func uploadWithResponse(preview: PreviewClosure? = nil) async throws -> URLResponse {
		try await sendRequest(preview: preview).response
	}
}
