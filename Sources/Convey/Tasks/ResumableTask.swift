//
//  ResumableTask.swift
//
//
//  Created by Ben Gottlieb on 2/15/24.
//

import Foundation

public protocol ResumableTask: CustomHTTPHeaders, ServerPATCHTask {
	var bytesUploaded: Int { get }
	var chunkSize: Int? { get }
	var fullData: Data? { get }
	var sourceURL: URL? { get }
}

public extension ResumableTask {
	var contentType: String? { "application/offset+octet-stream" }
	var path: String { "" }
	
	var customHTTPHeaders: ConveyHeaders {
		[
			"Tus-Resumable": "1.0.0",
			"Upload-Offset": "\(bytesUploaded)",
		]
	}
	
	func checkPreviousByteCount() async throws -> Int {
		let headers = try await head()
		
		guard let offset = headers.first(where: { $0.name == "Upload-Offset" }) else { return 0 }
		
		return Int(offset.value) ?? 0
	}
	
	var dataToUpload: Data? {
		if let fullData {
			return fullData.chunk(startingAt: bytesUploaded, maxSize: chunkSize)
		}
		
		if let sourceURL, let data = try? Data(contentsOf: sourceURL) {
			return data.chunk(startingAt: bytesUploaded, maxSize: chunkSize)
		}
		
		return nil
	}
}

private extension Data {
	func chunk(startingAt: Int, maxSize: Int?) -> Data {
		let remainder = startingAt == 0 ? self : suffix(from: startingAt)
		if let maxSize, maxSize < remainder.count {
			return remainder.prefix(maxSize)
		}
		return remainder
	}
}

