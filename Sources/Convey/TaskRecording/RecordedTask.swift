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
	var responseData: Data?
	var data: Data?
	var startedAt: Date
	var duration: TimeInterval?
	var error: String?
	var downloadSize: Int?
	var appLaunchedAt: TimeInterval
	var sessionStartedAt: TimeInterval?
	
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
		appLaunchedAt = launchedAt.timeIntervalSinceReferenceDate
		
		if let request = info.request {
			requestData = try? JSONEncoder().encode(request)
		}

		if let response = info.response {
			responseData = try? JSONEncoder().encode(response)
		}
	}
}
