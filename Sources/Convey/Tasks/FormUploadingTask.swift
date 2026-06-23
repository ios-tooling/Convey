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
		keys.sorted().compactMap { key in
			guard let value = self[key] else { return nil }
			return "\(key.formURLEncoded)=\("\(value)".formURLEncoded)"
		}
		.joined(separator: "&")
	}
}

private extension String {
	var formURLEncoded: String {
		addingPercentEncoding(withAllowedCharacters: .formURLEncodedAllowed) ?? self
	}
}

private extension CharacterSet {
	// Unreserved characters per RFC 3986; everything else is percent-encoded.
	static let formURLEncodedAllowed: CharacterSet = {
		var set = CharacterSet.alphanumerics
		set.insert(charactersIn: "-._~")
		return set
	}()
}
