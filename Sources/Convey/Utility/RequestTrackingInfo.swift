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
	var echoStyle: TaskEchoStyle
	
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
		echoStyle = task is any NonEchoingTask ? .hiddenUnlessError : task.echoStyle
	}
	
	func save() async {
		if echoStyle == .hidden { return }
		if echoStyle == .hiddenUnlessError, error == nil { return }
		
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
		fullDescription(limit: 1024)
	}
	
	func fullDescription(limit: UInt64) -> String {
		var result = endSeparator + minimalDescription
		
		if let error {
			result += "\n⚠️ \(error)"
		}
		result += separator

		if let request {
			result += "\(request.description)"
			
			if let httpBody {
				if httpBody.count < limit {
					result += "\n\(String(data: httpBody, encoding: .utf8) ?? "[binary data]")\n"
				} else {
					result += "\nPayload: \(httpBody.count) bytes\n"
				}
			}
			result += separator
		}
		
		if let status = response?.statusCode {
			result += "Status: \(status)\n"
		}
		
		if let headers = response?.allHeaderFields as? Headers {
			result += headers.description
			result += separator
		}
		
		if let data, let visible = data.reportedData(limit: limit) {
			result += "\(visible.debugDescription)"
		}
		
		result += endSeparator
		return result
	}
}
