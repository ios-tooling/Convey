//
//  RecordedTask.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/25/25.
//

import SwiftData
import Foundation

@available(iOS 17, macOS 14, watchOS 10, *)
@Model class RecordedTask {
	var url: URL?
	var name: String
	var blurb: String
	var requestData: Data?
	@Attribute(.externalStorage) var responseData: Data?
	@Attribute(.externalStorage) var httpBody: Data?
	@Attribute(.externalStorage) var data: Data?
	var uploadSize: Int?
	var downloadSize: Int?
	var startedAt: Date
	var duration: TimeInterval?
	var error: String?
	var appLaunchedAt: TimeInterval
	var sessionStartedAt: TimeInterval?
	var isGzipped = false
	var method: String
	
	var suggestedFilename: String {
		name + "@" + startedAt.formatted().replacingOccurrences(of: "/", with: "∕").replacingOccurrences(of: ":", with: "˸") + ".json"
	}
	
	var request: CodableURLRequest? {
		guard let requestData else { return nil }
		
		return try? JSONDecoder().decode(CodableURLRequest.self, from: requestData)
	}
	
	var sessionStartedAtDate: Date? { sessionStartedAt == nil ? nil : Date(timeIntervalSinceReferenceDate: sessionStartedAt!) }
	var appLaunchedAtDate: Date { Date(timeIntervalSinceReferenceDate: appLaunchedAt) }

	
	init(info: RequestTrackingInfo, launchedAt: Date) {
		url = info.url
		name = info.taskName
		blurb = info.taskDescription
		duration = info.duration
		startedAt = info.startedAt
		error = info.error
		downloadSize = info.data?.count
		data = info.data
		method = info.method
		appLaunchedAt = launchedAt.timeIntervalSinceReferenceDate
		httpBody = info.httpBody
		uploadSize = httpBody?.count

		if let request = info.request {
			requestData = try? JSONEncoder().encode(request)
			isGzipped = info.isGzipped
		}

		if let response = info.response {
			responseData = try? JSONEncoder().encode(response)
		}
	}
}
