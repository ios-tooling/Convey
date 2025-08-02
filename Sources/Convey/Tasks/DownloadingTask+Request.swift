//
//  DownloadingTask+Request.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/19/25.
//

import Foundation

public extension DownloadingTask {
	var shouldGZIPUploads: Bool {
		guard let uploader = (self as? any UploadingTask) else { return false }
		
		if server.configuration.enableGZipUploads, configuration?.gzip ?? uploader.gzip {
			return true
		}
		return false
	}
	
	var request: URLRequest {
		get async throws {
			let url = await url
			var request = URLRequest(url: url)
			request.httpMethod = method.rawValue.uppercased()
			
			let allHeaders: [Header] = try await (configuration.headers?.headersArray ?? []) + headers.headersArray
			
			for header in allHeaders {
				request.addValue(header.value, forHTTPHeaderField: header.name)
			}
			
			if let uploader = (self as? any UploadingTask), var uploadData = try await uploader.uploadData {
				if shouldGZIPUploads { uploadData = try uploadData.gzipped() }

				request.httpBody = uploadData
				
				if server.configuration.enableGZipUploads, configuration.gzip ?? uploader.gzip {
					request.addValue("\(uploadData.count)", forHTTPHeaderField: Constants.Headers.contentLength)
					request.addValue("gzip", forHTTPHeaderField: Constants.Headers.contentEncoding)
				}
			}
			if request.allHTTPHeaderFields?[Constants.Headers.contentType] == nil, let type = (self as? any UploadingTask)?.contentType {
				request.addValue(type, forHTTPHeaderField: Constants.Headers.contentType)
			}
			
			if let cookies = configuration.cookies {
				let fields = HTTPCookie.requestHeaderFields(with: cookies)
				for (key, value) in fields {
					request.addValue(value, forHTTPHeaderField: key)
				}
			}
			
			request.timeoutInterval = configuration.timeout ?? server.configuration.defaultTimeout

			return request
		}
	}
}
