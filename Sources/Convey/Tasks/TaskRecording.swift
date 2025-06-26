//
//  UnrecordedTask.swift
//  
//
//  Created by Ben Gottlieb on 6/10/24.
//

import Foundation

@ConveyActor public struct RecordedTask {
	public var task: (any ServerConveyable)?
	public var recording: String = ""
	
	public var startedAt: Date?
	public var completedAt: Date?
	public var url: URL?
	public var request: URLRequest?
	public var download: Data?
	public var cachedResponse: Data?

	var fields: [ServerTaskComponent] { (task as? any UnrecordedTask)?.exposedComponents ?? ServerTaskComponent.allCases }
	
	static nonisolated let separator = "\n=====================================\n"
	var output: String {
		var results = "====================================="
		
		if let task {
			results += " Echoing Request \(type(of: task))\n"
		} else {
			results += "\n"
		}
		
		
		for field in fields {
			switch field {
			case .url:
				if let url = request?.url {
					results += "[\(request?.httpMethod ?? "UNKNOWN METHOD")] \(url.absoluteString)\(Self.separator)"
				}
				
			case .headers:
				if let headers = request?.allHTTPHeaderFields, !headers.isEmpty {
					results += "Headers\n"
					for (key, value) in headers {
						results = results + "\t• " + key + ": " + value + "\n"
					}
					results += Self.separator
				}

			case .request:
				if var request {
					request.allHTTPHeaderFields = [:]
					request.httpBody = nil
				
					results += "[\(request.httpMethod ?? "UNKNOWN METHOD")] \(request.description)\(Self.separator)"
				}
			
			case .upload:
				if let body = request?.httpBody {
					let output: String
					if task is any GZipEncodedUploadingTask, let data = try? body.gunzipped() {
						output = String(data: data, encoding: .utf8) ?? String(data: body, encoding: .ascii) ?? "unable to stringify payload"
					} else {
						output = String(data: body, encoding: .utf8) ?? String(data: body, encoding: .ascii) ?? "unable to stringify payload"
					}
					
					results += output + Self.separator
				}

			case .download:
				if let body = download ?? cachedResponse {
					if let json = body.prettyJSON {
						results += json + Self.separator
					} else {
						let output = String(data: body, encoding: .utf8) ?? String(data: body, encoding: .ascii) ?? "unable to stringify response"
						results += output + Self.separator
					}
				}
			}

		}
		
		return results
	}
	
	func echo() {
		
		
//		"\(type(of: task.wrappedTask)) Response ======================\n \(String(data: log, encoding: .utf8) ?? String(data: log, encoding: .ascii) ?? "unable to stringify response")\n======================", for: task)
//
		print(output)
	}
}

public enum ServerTaskComponent: CaseIterable { case url, headers, request, upload, download }

public extension UnrecordedTask {
	var exposedComponents: [ServerTaskComponent] { [] }
}
