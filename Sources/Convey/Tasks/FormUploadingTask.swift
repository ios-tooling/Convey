//
//  FormUploadingTask.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/20/25.
//

import Foundation

public protocol FormUploadingTask: UploadingTask where UploadPayload == Data {
	var formFields: [String: Sendable]? { get }
	var shouldURLEncodePayload: Bool { get }
}

public extension FormUploadingTask {
	var contentType: String? { "application/x-www-form-urlencoded" }
	var uploadPayload: Data? { nil }
	var uploadData: Data? { formFields?.formURLEncodedData(shouldURLEncode: shouldURLEncodePayload) }
	var shouldURLEncodePayload: Bool { false }
}

public extension [String: any Sendable] {
	func formURLEncodedData(shouldURLEncode: Bool) -> Data { formURLEncodedString(shouldURLEncode: shouldURLEncode).data(using: .utf8) ?? Data() }

	func formURLEncodedString(shouldURLEncode: Bool) -> String {
		if shouldURLEncode {
			return keys.sorted().compactMap { key in
				guard let value = self[key] else { return nil }
				return "\(key.formURLEncoded)=\("\(value)".formURLEncoded)"
			}
			.joined(separator: "&")
		} else {
			var upload = ""
			let sortedKeys = keys.sorted()
			
			for key in sortedKeys {
				guard let value = self[key] else { continue }
				upload += "\(key)=\(value)&"
			}
			return upload
		}
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
