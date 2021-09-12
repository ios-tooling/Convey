//
//  PayloadUploadingTask.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 9/11/21.
//

import Suite

public extension PayloadDownloadingTask where Self: PayloadUploadingTask {
	func upload() -> AnyPublisher<DownloadPayload, HTTPError> {
		fetch()
	}
}

public extension PayloadUploadingTask {
	func upload() -> AnyPublisher<Data, HTTPError> {
		run()
	}

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
