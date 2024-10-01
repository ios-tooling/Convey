//
//  ServerTask+Extension.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 8/19/22.
//

import Foundation

public extension ServerTask {
	var server: ConveyServer { DefaultServer.server }

	func postProcess(response: ServerResponse) async throws { }
	var path: String { "" }

	var url: URL {
		let nonParameterized = (self.wrappedTask as? CustomURLTask)?.customURL ?? server.url(forTask: self)
		if let parameters = (self.wrappedTask as? ParameterizedTask)?.parameters, !parameters.isEmpty {
			var components = URLComponents(url: nonParameterized, resolvingAgainstBaseURL: true)
			
			if let params = parameters as? [String: String] {
				components?.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }.sorted { $0.name < $1.name }
			} else if let params = parameters as? [URLQueryItem] {
				components?.queryItems = params.sorted { $0.name < $1.name }
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
	func postProcess(payload: DownloadPayload) async throws { }
	
	func decode(data: Data, decoder possible: JSONDecoder? = nil) throws -> DownloadPayload {
		let decoder = possible ?? server.defaultDecoder
		return try decoder.decode(DownloadPayload.self, from: data)
	}
	
	func cachedPayload(decoder: JSONDecoder? = nil) -> DownloadPayload? {
		guard let data = cachedData else { return nil }

		do {
			return try decode(data: data, decoder: decoder)
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
		let encoder = (self.wrappedTask as? CustomJSONEncoderTask)?.jsonEncoder ?? server.defaultEncoder
		
		do {
			return try encoder.encode(payload)
		} catch {
			server.taskFailed(self, error: error)
			return nil
		}
	}
}
