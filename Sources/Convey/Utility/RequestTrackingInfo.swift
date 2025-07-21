//
//  RequestTrackingInfo.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/21/25.
//

import Foundation

public struct RequestTrackingInfo: Sendable, Codable {
	let taskName: String
	let taskDescription: String
	
	var request: CodableURLRequest?
	var response: CodableURLResponse?
	var duration: TimeInterval?
	var error: String?
	
	var urlRequest: URLRequest? {
		get { nil }
		set { if let newValue { request = .init(newValue) }}
	}

	var urlResponse: URLResponse? {
		get { nil }
		set { if let newValue { response = .init(newValue) }}
	}

	var data: Data?
	
	init<T: DownloadingTask>(_ task: T) {
		taskName = String(describing: type(of: task))
		taskDescription = String(describing: task)
	}
	
	var minimalDescription: String {
		var result = "☎️ \(taskName)"
		
		if let duration {
			result += " (\(String(format: "%.2f", duration))s)"
		}
		
		return result
	}
	
	var fullDescription: String {
		var result = minimalDescription
		
		if let error {
			result += "\n⚠️ \(error)"
		}

		if let request {
			result += "\n\(request.description)"
		}
		
		return result
	}
}
