//
//  FormUploadingTask.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/20/25.
//

import Foundation

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

