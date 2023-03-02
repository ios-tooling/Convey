//
//  ServerTask+Rerunnable.swift
//  
//
//  Created by Ben Gottlieb on 12/19/22.
//

import Foundation

public protocol RerunnableServerTask {
	func rerunnableRequest(from serverReturned: ServerReturned) -> URLRequest?
	var previousResult: ServerReturned? { get set }
}

public extension RerunnableServerTask {
	func runRepeatedly(completion: @escaping (ServerReturned) -> Bool) async throws {
		
	}
}

public extension PayloadDownloadingTask where Self: RerunnableServerTask {
	func downloadRepeatedly(decoder: JSONDecoder? = nil, preview: PreviewClosure? = nil, completion: @escaping (DownloadPayload) -> Bool) async throws {
		var task = self
		while true {
			do {
				let result = try await task.downloadWithResponse(caching: .skipLocal, decoder: decoder, preview: preview)
				if !completion(result.payload) { return }
				task.previousResult = result.response
			} catch ConveyServerError.endOfRepetition {
				return
			} catch {
				throw error
			}
		}
	}
}
