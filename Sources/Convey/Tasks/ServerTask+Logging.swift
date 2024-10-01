//
//  ServerTask+Logging.swift
//  
//
//  Created by Ben Gottlieb on 9/15/21.
//

import Foundation

extension ConveyServer {
	nonisolated func setupLoggingDirectory() -> URL? {
		guard let url = logDirectory else { return nil }
		
		try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
		return url
	}
}
extension ServerTask {
	public func logged() async -> Self {
		await server.taskManager.incrementOneOffLog(for: self)
		return self
	}
	
	public var isOneOffLogged: Bool {
		get async { server.taskManager.oneOffTypes.value.contains(String(describing: type(of: self))) }
	}
	
	nonisolated func logFilename(for date: Date) -> String {
		let timestamp = date.timeIntervalSince(server.launchedAt)
        let name = "\(Int(timestamp)).txt"
        if #available(iOS 15, macOS 12, watchOS 8, tvOS 15.0, *) {
            return "\(date.filename) \(name)"
        }
        return name
	}
	
	nonisolated func preLog(startedAt: Date, request: URLRequest) async {
		if await self.isEchoing {
			print(" ====================== Echoing Request \(type(of: self)) ======================\n \(request)\n============================================")
		}
		guard let url = server.setupLoggingDirectory()?.appendingPathComponent(logFilename(for: startedAt)) else { return }
		
		let data = request.descriptionData(maxUploadSize: server.maxLoggedUploadSize)
		try? data.write(to: url)
	}
	
//	func postLog(startedAt: Date, request: URLRequest, data: Data?, response: URLResponse?) {
//		guard let url = server.setupLoggingDirectory()?.appendingPathComponent(logFilename(for: startedAt)) else {
//			if self.isEchoing { print(String(data: loggingOutput(startedAt: startedAt, request: request, data: data, response: response), encoding: .utf8) ?? "unable to stringify response") }
//			return
//		}
//		try? FileManager.default.removeItem(at: url)
//
//		let output = loggingOutput(startedAt: startedAt, request: request, data: data, response: response)
//		if self.isEchoing {
//			print("====================== Echoing Response \(type(of: self)) ======================\n \(String(data: output, encoding: .utf8) ?? "unable to stringify response")\n======================")
//		}
//		try? output.write(to: url)
//	}
	
	func loggingOutput(startedAt: Date? = nil, request: URLRequest?, data: Data?, response: URLResponse?, includeMarkers: Bool = true) -> Data {
		var output = Data()
		
		if let startedAt {
			output = "Started at: \(startedAt.timeLabel), took: \(abs(startedAt.timeIntervalSinceNow))s\n".data(using: .utf8) ?? Data()
		}
		
		output += (request?.descriptionData(maxUploadSize: server.maxLoggedUploadSize)) ?? Data()
		
		if let responseData = response?.descriptionData {
			if includeMarkers { output += "\n\n⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗\n\n".data(using: .utf8) ?? Data() }
			output += responseData
		}
		
		if let body = data, body.count < server.maxLoggedDownloadSize {
			if includeMarkers { output += "\n\n⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗\n\n".data(using: .utf8) ?? Data() }
			do {
				let json = try JSONSerialization.jsonObject(with: body, options: [])
				let jsonData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted])
				
				output += jsonData
			} catch {
				output += body
			}
		}
		return output
	}
}

public extension URLResponse {
	func detailedDescription() -> String {
		var result = ""
		
		if let httpResponse = self as? HTTPURLResponse {
			result += "Status: \(httpResponse.statusCode) \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))\n"
			result += "Headers\n"
			for (header, value) in httpResponse.allHeaderFields {
				result += "\t\(header): \(value)\n"
			}
			
		}
		
		if let mimeType = mimeType { result += "MimeType: \(mimeType)\n" }
		if expectedContentLength > 0 { result += "Expected Content Length: \(expectedContentLength)\n" }
		if let textEncodingName = textEncodingName { result += "Text Encoding: \(textEncodingName)\n" }
		if let suggestedFilename = suggestedFilename { result += "Suggested File Name: \(suggestedFilename)\n" }

		return result
	}
	
	var descriptionData: Data {
		detailedDescription().data(using: .utf8) ?? Data()
	}
}

public extension URLRequest {
	func descriptionData(maxUploadSize: Int) -> Data {
		let desc = detailedDescription(includingBody: false) + "\n"
		var bodyData = httpBody
		
		if let body = httpBody {
			do {
				let json = try JSONSerialization.jsonObject(with: body, options: [])
				let jsonData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted])
				
				bodyData = jsonData
			} catch { }
		}
		
		var results = desc.data(using: .utf8) ?? Data()
		if let body = bodyData {
			results += "Payload ┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳┳\n\n".data(using: .utf8) ?? Data()
			if body.count < maxUploadSize {
				results.append(body)
			} else {
				results.append("\(body.count / 1024) k".data(using: .utf8) ?? Data())
			}
			results += "\n\n┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻┻\n".data(using: .utf8) ?? Data()
		}
		
		return results
	}
	
	func detailedDescription(includingBody: Bool) -> String {
		var result = ""
		
		result += "\(httpMethod ?? "[MISSING]") \(url?.absoluteString ?? "NO URL")\n"
		result += "Timeout: \(timeoutInterval)\n"
		if let main = mainDocumentURL {
			result += "Main Document URL: \(main.absoluteString)\n"
		}
		result += "Handles cookies: \(httpShouldHandleCookies)\n"
		
		if let headers = allHTTPHeaderFields {
			result += "Headers\n"
			for (header, value) in headers {
				result += "\t\(header): \(value)\n"
			}
		}
		
		return result
	}
}

extension Date {
    var timeLabel: String {
        let time = timeIntervalSinceReferenceDate
        let milliseconds = Int(time * 1000) % 1000
        let seconds = Int(time) % 60
        let minutes = (Int(time) / 60) % 60
        let hours = (Int(time) / 3600) % 24
        
        return String(format: "%d:%02d:%02d.%d", hours, minutes, seconds, milliseconds)
    }
}
