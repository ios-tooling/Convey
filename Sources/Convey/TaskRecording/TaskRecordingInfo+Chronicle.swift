//
//  TaskRecordingInfo+Chronicle.swift
//  Convey
//
//  Created by Ben Gottlieb on 3/21/26.
//

import Foundation
import Chronicle

extension TaskRecordingInfo {
	func logToChronicle(file: String = #file, function: String = #function, line: Int = #line) {
		guard #available(iOS 17, macOS 14, *), Chronicle.instance.isConfigured else { return }
		
		let endTime = duration.map { startedAt.addingTimeInterval($0) }
		let statusCode = response?.statusCode
		
		var errorMessage = error
		if errorMessage == nil, let statusCode {
			let throwingCategories = ConveyServer.default.configuration.throwingStatusCategories
			let statusFamily = (statusCode / 100) * 100
			if throwingCategories.contains(statusFamily) {
				errorMessage = "HTTP \(statusCode)"
			}
		}
		
		if let url {
			Chronicle.network(
				url: url,
				method: method,
				requestHeaders: request?.allHTTPHeaderFields,
				requestBody: httpBody,
				statusCode: statusCode,
				responseHeaders: response?.allHeaderFields,
				responseBody: data,
				error: errorMessage,
				wasCancelled: wasCancelled,
				metrics: NetworkMetrics(
					startTime: startedAt,
					endTime: endTime ?? startedAt,
					bytesSent: Int64(httpBody?.count ?? 0),
					bytesReceived: Int64(data?.count ?? 0)
				),
				file: file,
				function: function,
				line: line
			)
		}
	}
}

private struct ConveyTaskError: LocalizedError {
	let message: String
	let statusCode: Int?

	var errorDescription: String? { message }
}
