//
//  PayloadUploadingTask.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 9/11/21.
//

import Foundation
import Combine

public extension PayloadDownloadingTask where Self: DataUploadingTask {
	func upload(decoder: JSONDecoder? = nil, preview: PreviewClosure? = nil) -> AnyPublisher<(payload: DownloadPayload, response: URLResponse), Error> {
		requestPayload(caching: .skipLocal, decoder: decoder, preview: preview)
			.mapError { $0 as Error }
			.eraseToAnyPublisher()
	}
}

public extension DataUploadingTask {
	func upload(preview: PreviewClosure? = nil) -> AnyPublisher<Int, Error> {
		internalRequestData(preview: preview)
			.map { ($0.response as? HTTPURLResponse)?.statusCode ?? 500 }
			.mapError { $0 as Error }
			.eraseToAnyPublisher()
	}
}

extension JSONUploadingTask {
	public var dataToUpload: Data? {
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
