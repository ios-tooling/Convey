//
//  ServerTask+Extension.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 8/19/22.
//

import Foundation

public extension ServerTask {
	var server: Server { (self as? CustomServerTask)?.customServer ?? Server.serverInstance ?? Server.setupDefault() }

	func postprocess(response: ServerReturned) { }

	var url: URL {
		let nonParameterized = (self as? CustomURLTask)?.customURL ?? server.url(forTask: self)
		if let parameters = (self as? ParameterizedTask)?.parameters, !parameters.isEmpty {
			var components = URLComponents(url: nonParameterized, resolvingAgainstBaseURL: true)
			
			if let params = parameters as? [String: String] {
				components?.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
			} else if let params = parameters as? [URLQueryItem] {
				components?.queryItems = params
			}

			if let newURL = components?.url { return newURL }
		}

		return nonParameterized
	}

	var cachedData: Data? {
		DataCache.instance.fetchLocal(for: url)?.data
	}
}

public extension PayloadDownloadingTask {
	func postprocess(payload: DownloadPayload) { }
	
	func cachedPayload(decoder: JSONDecoder? = nil) -> DownloadPayload? {
		guard let data = cachedData else { return nil }
		let decoder = decoder ?? server.defaultDecoder
		
		do {
			return try decoder.decode(DownloadPayload.self, from: data)
		} catch {
			print("Local requestPayload failed for \(DownloadPayload.self) \(url)\n\n \(error)\n\n\(String(data: data, encoding: .utf8) ?? "--")")
			return nil
		}
	}
}

public extension JSONUploadingTask {
	var contentType: String? { "application/json" }
	var dataToUpload: Data? {
		do {
			guard let json = jsonToUpload else { return nil }
			return try JSONSerialization.data(withJSONObject: json, options: [])
		} catch {
			print("Error preparing upload: \(error)")
			return nil
		}
	}
}

public extension PayloadUploadingTask {
	var contentType: String? { "application/json" }
	var dataToUpload: Data? {
		guard let payload = uploadPayload else { return nil }
		let encoder = (self as? CustomJSONEncoderTask)?.jsonEncoder ?? server.defaultEncoder
		
		do {
			return try encoder.encode(payload)
		} catch {
			server.handle(error: error, from: self)
			return nil
		}
	}
}
