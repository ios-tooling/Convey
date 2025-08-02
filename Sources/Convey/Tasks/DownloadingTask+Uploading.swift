//
//  DownloadingTask+Uploading.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/19/25.
//

import Foundation

public extension IgnoredResultsTask {
	func upload() async throws {
		let _ = try await download()
	}
}

public extension UploadingTask {
	var gzip: Bool { server.configuration.enableGZipDownloads }
	var uploadData: Data? { get async throws {
		guard let uploadPayload else { return nil }
		let data = try encoder.encode(uploadPayload)
		
		return data
	} }
	
	var encoder: JSONEncoder { server.configuration.defaultEncoder }
	var contentType: String? { UploadPayload.self == Data.self ? "application/json" : nil }
}


public extension DataUploadingTask {
	var uploadData: Data? { uploadPayload }
}
