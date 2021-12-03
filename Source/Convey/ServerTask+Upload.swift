//
//  PayloadUploadingTask.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 9/11/21.
//

import Foundation
import Combine

public extension PayloadDownloadingTask where Self: DataUploadingTask {
	func upload(decoder: JSONDecoder? = nil, preview: PreviewClosure? = nil) -> AnyPublisher<DownloadPayload, Error> {
		fetch(caching: .skipLocal, decoder: decoder, preview: preview)
			.mapError { $0 as Error }
			.eraseToAnyPublisher()
	}
}

extension JSONUploadingTask {
	public var uploadData: Data? {
		do {
			guard let json = uploadJSON else { return nil }
			return try JSONSerialization.data(withJSONObject: json, options: [])
		} catch {
			print("Error preparing upload: \(error)")
			return nil
		}
	}
}

public extension DataUploadingTask {
	func upload(preview: PreviewClosure? = nil) -> AnyPublisher<Int, Error> {
		submit(caching: .skipLocal, preview: preview)
			.map { $0.response.statusCode }
			.mapError { $0 as Error }
			.eraseToAnyPublisher()
	}
}

public extension PayloadUploadingTask {
	var uploadData: Data? {
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
