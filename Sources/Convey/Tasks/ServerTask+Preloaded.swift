//
//  ServerTask+Preloaded.swift
//
//
//  Created by Ben Gottlieb on 11/25/23.
//

import Foundation

public extension PayloadDownloadingTask {
	func preloadedPayload(filename: String? = nil, decoder: JSONDecoder? = nil) throws -> DownloadPayload {
		let url = preloadedSource(filename: filename)
		let data = try Data(contentsOf: url)
		return try decode(data: data, decoder: decoder)
	}
	
	func preloadedSource(filename: String?) -> URL {
		if let filename { return Bundle.main.bundleURL.appendingPathComponent(filename + ".json") }
		if let url = (self as? ArchivingTask)?.archiveURL, FileManager.default.fileExists(atPath: url.path) { return url }
		return Bundle.main.bundleURL.appendingPathComponent(String(describing: Self.self) + ".json")
	}
}
