//
//  ServerTask+AsyncUpload.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 10/31/21.
//

import Foundation

@available(macOS 11, iOS 13.0, watchOS 7.0, *)
public extension PayloadDownloadingTask where Self: DataUploadingTask {
	func upload(decoder: JSONDecoder? = nil, preview: PreviewClosure? = nil) async throws -> DownloadPayload {
		try await fetch(caching: .reloadIgnoringLocalCacheData, decoder: decoder, preview: preview)
	}
}

@available(macOS 11, iOS 13.0, watchOS 7.0, *)
public extension DataUploadingTask {
	func upload(preview: PreviewClosure? = nil) async throws -> Int {
		try await submit(caching: .reloadIgnoringLocalCacheData, preview: preview).response.statusCode
	}
}
