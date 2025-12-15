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
	
	var computedTimeout: TimeInterval {
		let config = configuration?.timeout ?? server.configuration.defaultTimeout
		let resource = self.timeoutIntervalForResource ?? 0
		let request = self.timeoutIntervalForRequest ?? 0
		
		return max(config, max(resource, request))
	}
	
	var request: URLRequest {
		get async throws {
			let url = await url
			var request = URLRequest(url: url)
			request.httpMethod = method.rawValue.uppercased()
			request.timeoutInterval = computedTimeout
			
			var allHeaders = try await server.headers(for: self).headersArray
			let taskHeaders: [Header] = try await (configuration.headers?.headersArray ?? []) + headers.headersArray
			
			allHeaders += taskHeaders
			
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
			if request.allHTTPHeaderFields?[Constants.Headers.contentType] == nil {
				if let type = (self as? any UploadingTask)?.contentType {
					request.addValue(type, forHTTPHeaderField: Constants.Headers.contentType)
				} else if let data = request.httpBody, (try? JSONSerialization.jsonObject(with: data, options: [])) != nil {
					request.addValue(Constants.applicationJson, forHTTPHeaderField: Constants.Headers.contentType)
				}
			}
			
			if let cookies = configuration.cookies {
				let fields = HTTPCookie.requestHeaderFields(with: cookies)
				for (key, value) in fields {
					request.addValue(value, forHTTPHeaderField: key)
				}
			}
			
			request.timeoutInterval = computedTimeout

			return request
		}
	}
}
