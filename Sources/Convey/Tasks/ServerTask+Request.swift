//
//  ServerTask+Request.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 9/11/21.
//

import Foundation
import Combine

public extension ServerTask {
	var cachedEtag: String? { ETagStore.instance.eTag(for: url) }
	
	func buildRequest() async throws -> URLRequest {
		if let rerunnable = self as? RerunnableServerTask, let previous = rerunnable.previousResult {
			if let newRequest = try await rerunnable.rerunnableRequest(from: previous) { return newRequest }
			throw ConveyServerError.endOfRepetition
		}

		if let custom = self as? CustomURLRequestTask {
			return try await custom.customURLRequest
		}

		return try await defaultRequest()
	}

	func defaultRequest() async throws -> URLRequest {
		var request = URLRequest(url: url)
		var isGzipped = self is GZipEncodedUploadingTask
		
		request.timeoutInterval = (self as? CustomTimeoutTask)?.timeout ?? server.defaultTimeout
		request.httpMethod = httpMethod
		request.cachePolicy = .reloadIgnoringLocalCacheData
		if let dataProvider = self as? DataUploadingTask {
			if request.httpMethod == "GET" { request.httpMethod = "POST" }
			if var data = dataProvider.dataToUpload {
				if isGzipped {
					do {
						data = try data.gzipped()
					} catch {
						print("Failed to gzip upload data: \(error)")
						isGzipped = false
					}
				}
				request.httpBody = data
			}
			if request.allHTTPHeaderFields?[ServerConstants.Headers.contentType] == nil {
				if let type = dataProvider.contentType {
					request.addValue(type, forHTTPHeaderField: ServerConstants.Headers.contentType)
				}
				if isGzipped {
					request.addValue("gzip", forHTTPHeaderField: ServerConstants.Headers.contentEncoding)
				}
			}
		}
		request.allHTTPHeaderFields = try await server.standardHeaders(for: self)
		if let tagged = self as? TaggedTask {
			request.addValue(tagged.requestTag, forHTTPHeaderField: ServerConstants.Headers.tag)
		}
		
		if let additionalHeaders = (self as? CustomHTTPHeaders)?.customHTTPHeaders {
			for (value, header) in additionalHeaders {
				request.addValue(header, forHTTPHeaderField: value)
			}
		}
		
		if self is ETagCachedTask, let etag = cachedEtag, DataCache.instance.hasCachedValue(for: url) {
			request.addValue(etag, forHTTPHeaderField: ServerConstants.Headers.ifNoneMatch)
		}
		
		if let cookies = (self as? CookieSendingTask)?.cookies {
			request.addValue(cookies.cookieHeaderValue, forHTTPHeaderField: "Cookie")
		}
		
		return request
	}

	var httpMethod: String {
		if let custom = self as? CustomHTTPMethodTask { return custom.customHTTPMethod }
		
		if self is ServerPOSTTask { return "POST" }
		if self is ServerPUTTask { return "PUT" }
		if self is ServerPATCHTask { return "PATCH" }
		if self is ServerDELETETask { return "DELETE" }
		return "GET"
	}
}
