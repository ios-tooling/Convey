//
//  ServerTask+Uploading.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/19/25.
//

import Foundation

public protocol JSONUploadingTask: UploadingTask where UploadPayload == Data {
	var json: [String: Sendable]? { get }
}

public extension JSONUploadingTask {
	var contentType: String? { "application/json" }
	var json: [String: Sendable]? { nil }
	var uploadPayload: Data? { nil }
	var uploadData: Data? { get async throws {
		guard let uploadPayload else { return nil }
		return try JSONSerialization.data(withJSONObject: uploadPayload, options: [])
	}}
}

public protocol FormUploadingTask: UploadingTask where UploadPayload == Data {
	var formFields: [String: Sendable]? { get }
}

public extension FormUploadingTask {
	var contentType: String? { "application/x-www-form-urlencoded" }
	var uploadPayload: Data? { nil }
	var uploadData: Data? { formFields?.formURLEncodedData }
}

public extension [String: any Sendable] {
	var formURLEncodedData: Data { formURLEncodedString.data(using: .utf8) ?? Data() }
	var formURLEncodedString: String {
		var upload = ""
		let sortedKeys = keys.sorted()
		
		for key in sortedKeys {
			guard let value = self[key] else { continue }
			upload += "\(key)=\(value)&"
		}
		
		return upload
	}
}


public extension UploadingTask {
	var gzip: Bool { server.configuration.enableGZipDownloads }
	var uploadData: Data? { get async throws {
		guard let uploadPayload else { return nil }
		let data = try encoder.encode(uploadPayload)
		
		if await configuration.gzip ?? gzip {
			return try data.gzipped()
		}
		
		return data
	} }
	var encoder: JSONEncoder { server.configuration.defaultEncoder }
	var contentType: String? { UploadPayload.self == Data.self ? "application/json" : nil }
}


public extension DataUploadingTask {
	var uploadData: Data? { uploadPayload }
}
