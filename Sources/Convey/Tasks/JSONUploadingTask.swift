//
//  JSONUploadingTask.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/20/25.
//

import Foundation

public protocol JSONUploadingTask: UploadingTask where UploadPayload == Data {
	var json: [String: Sendable]? { get }
}

public extension JSONUploadingTask {
	var contentType: String? { Constants.applicationJson }
	var json: [String: Sendable]? { nil }
	var uploadPayload: Data? { nil }
	var uploadData: Data? { get throws {
		guard let json else { return nil }
		return try JSONSerialization.data(withJSONObject: json, options: [])
	}}
}

