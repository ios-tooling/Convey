//
//  ServerTask+Preloaded.swift
//
//
//  Created by Ben Gottlieb on 11/25/23.
//

import Foundation

public extension PayloadDownloadingTask {
	func preloadedPayload(filename: String? = nil) throws -> DownloadPayload {
		let file = filename ?? String(describing: Self.self) + ".json"
		let url = Bundle.main.bundleURL.appendingPathComponent(file)
		let data = try Data(contentsOf: url)
		
		let decoder = server.defaultDecoder
		return try decoder.decode(DownloadPayload.self, from: data)
	}
}
