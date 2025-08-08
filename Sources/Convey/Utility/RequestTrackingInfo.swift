//
//  RequestTrackingInfo.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/21/25.
//

import Foundation

@ConveyActor public struct RequestTrackingInfo: Sendable, Codable {
	let taskName: String
	let taskDescription: String
	let method: String
	var url: URL?
	var startedAt = Date()
	var request: CodableURLRequest?
	var httpBody: Data?
	var isGzipped = false
	var response: CodableURLResponse?
	var duration: TimeInterval?
	var error: String?
	
	var separator = 		"\n##============================================================##\n"
	var endSeparator = 	"\n################################################################\n"

	var urlRequest: URLRequest? {
		get { nil }
		set { if let newValue {
			request = .init(newValue, includingBody: false)
			httpBody = newValue.httpBody
		}}
	}

	var ungzippedRequest: URLRequest? {
		get { request?.request(withData: httpBody) }
		set { if let newValue {
			isGzipped = true
			request = .init(newValue, includingBody: false)
			httpBody = newValue.httpBody
		}}
	}

	var urlResponse: URLResponse? {
		get { response?.response }
		set { if let newValue { response = .init(newValue) }}
	}

	var data: Data?
	
	init<T: DownloadingTask>(_ task: T) {
		taskName = String(describing: type(of: task))
		taskDescription = String(describing: task)
		method = task.method.rawValue.uppercased()
	}
	
	func save() async {
		if #available(iOS 17, macOS 14, watchOS 10, *) {
			await TaskRecorder.instance.record(info: self)
		}
	}
	
	var minimalDescription: String {
		var result = "☎️ \(taskName)"
		
		if let duration {
			result += " (\(String(format: "%.2f", duration))s)"
		}
		
		return result
	}
	
	var fullDescription: String {
		var result = endSeparator + minimalDescription
		
		if let error {
			result += "\n⚠️ \(error)"
		}
		result += separator

		if let request {
			result += "\(request.description)"
			result += separator
		}
		
		if let headers = response?.allHeaderFields as? Headers {
			result += headers.description
			result += separator
		}
		
		if let data, let visible = data.reportedData(limit: 2048) {
			result += "\(visible.debugDescription)"
		}
		
		result += endSeparator
		return result
	}
}
