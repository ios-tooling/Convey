//
//  ServerTask+Logging.swift
//  
//
//  Created by Ben Gottlieb on 9/15/21.
//

import Suite

extension Server {
	func setupLoggingDirectory() -> URL? {
		guard let url = logDirectory else { return nil }
		
		try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
		return url
	}
}
extension ServerTask {
	func logFilename(for date: Date) -> String {
		let timestamp = date.timeIntervalSince(server.launchedAt)
		return "\(date.localTimeString(date: .none, time: .abbr).replacingOccurrences(of: ":", with: "᠄ ")); \(timestamp.string(decimalPlaces: 6, padded: true)) - \(type(of: self)).txt"
	}
	
	func preLog(startedAt: Date, request: URLRequest) {
		guard let url = server.setupLoggingDirectory()?.appendingPathComponent(logFilename(for: startedAt)) else { return }
		
		let data = request.descriptionData
		try? data.write(to: url)
	}
	
	func postLog(startedAt: Date, request: URLRequest, data: Data?, response: URLResponse?) {
		guard let url = server.setupLoggingDirectory()?.appendingPathComponent(logFilename(for: startedAt)) else { return }
		try? FileManager.default.removeItem(at: url)

		var output = "Started at: \(startedAt.localTimeString(date: .short, time: .short)), took: \(abs(startedAt.timeIntervalSinceNow)) s\n".data(using: .utf8) ?? Data()
		output += request.descriptionData
		
		if let responseData = response?.descriptionData {
			output += "\n\n⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗\n\n".data(using: .utf8) ?? Data()
			output += responseData
		}
		
		if let body = data, body.count < server.maxLoggedDataSize {
			output += "\n\n⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗⍗\n\n".data(using: .utf8) ?? Data()
			do {
				let json = try JSONSerialization.jsonObject(with: body, options: [])
				let jsonData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted])
				
				output += jsonData
			} catch {
				output += body
			}
		}
		
		try? output.write(to: url)
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
	var descriptionData: Data {
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
			results.append(body)
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
