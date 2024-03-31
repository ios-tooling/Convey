//
//  FormURLEncodedUploadingTask.swift
//
//
//  Created by Ben Gottlieb on 12/21/23.
//

import Foundation

public extension FormURLEncodedUploadingTask {
	var dataToUpload: Data? { formFields.formURLEncodedData }
	var contentType: String? { "application/x-www-form-urlencoded" }
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

