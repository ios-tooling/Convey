//
//  File.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/19/25.
//

import Foundation

public extension DownloadingTask {
	var request: URLRequest {
		get async throws {
			let url = await url
			var request = URLRequest(url: url)
			request.httpMethod = method.rawValue
			
			let allHeaders: [Header] = await (configuration.headers?.headersArray ?? []) + headers.headersArray
			
			for header in allHeaders {
				request.addValue(header.value, forHTTPHeaderField: header.name)
			}
			
			if let uploader = (self as? any UploadingTask), let uploadData = try await uploader.uploadData {
				request.httpBody = uploadData
				
				if await configuration.gzip ?? uploader.gzip {
					request.addValue("\(uploadData.count)", forHTTPHeaderField: Constants.Headers.contentLength)
					request.addValue("gzip", forHTTPHeaderField: Constants.Headers.contentEncoding)
				}
			}
			if request.allHTTPHeaderFields?[Constants.Headers.contentType] == nil, let type = (self as? any UploadingTask)?.contentType {
				request.addValue(type, forHTTPHeaderField: Constants.Headers.contentType)
			}
			
			if let cookies = await configuration.cookies {
				let fields = HTTPCookie.requestHeaderFields(with: cookies)
				for (key, value) in fields {
					request.addValue(value, forHTTPHeaderField: key)
				}
			}

			return request
		}
	}
}
