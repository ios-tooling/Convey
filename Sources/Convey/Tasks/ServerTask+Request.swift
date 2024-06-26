//
//  ServerTask+Request.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 9/11/21.
//

import Foundation
import Combine

public extension ServerTask {
	var cachedEtag: String? {
		get async { await ETagStore.instance.eTag(for: url) }
	}
	
	func beginRequest(at startedAt: Date) async throws -> URLRequest {
		try await (self.wrappedTask as? PreFlightTask)?.preFlight()

		var request = try await buildRequest()
		request = try await server.preflight(self, request: request)
		await server.taskManager.begin(task: self, request: request, startedAt: startedAt)
		return request
	}

	func buildRequest() async throws -> URLRequest {
		if let custom = self.wrappedTask as? CustomURLRequestTask {
			return try await custom.customURLRequest
		}

		return try await defaultRequest()
	}

	func defaultRequest() async throws -> URLRequest {
		var request = URLRequest(url: url)
		var isGzipped = self is GZipEncodedUploadingTask
		
		request.timeoutInterval = (self.wrappedTask as? CustomTimeoutTask)?.timeout ?? server.defaultTimeout
		request.httpMethod = httpMethod
		request.cachePolicy = .reloadIgnoringLocalCacheData
		if let dataProvider = self.wrappedTask as? DataUploadingTask {
			if request.httpMethod == "GET" { request.httpMethod = "POST" }
			if var data = dataProvider.dataToUpload {
				if isGzipped {
					do {
						data = try data.gzipped()
						request.addValue("\(data.count)", forHTTPHeaderField: ServerConstants.Headers.contentLength)
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
		if let tagged = self.wrappedTask as? TaggedTask {
			request.addValue(tagged.requestTag, forHTTPHeaderField: ServerConstants.Headers.tag)
		}
		
		if let additionalHeaders = (self.wrappedTask as? CustomHTTPHeaders)?.customHTTPHeaders as? [String: String] {
			for (value, header) in additionalHeaders {
				request.addValue(header, forHTTPHeaderField: value)
			}
		}

		if let additionalHeaders = (self.wrappedTask as? CustomHTTPHeaders)?.customHTTPHeaders as? [ConveyHeader] {
			for header in additionalHeaders {
				request.addValue(header.value, forHTTPHeaderField: header.name)
			}
		}

		if self.wrappedTask is ETagCachedTask, let etag = await cachedEtag, DataCache.instance.hasCachedValue(for: url) {
			request.addValue(etag, forHTTPHeaderField: ServerConstants.Headers.ifNoneMatch)
		}
		
		if let cookies = (self.wrappedTask as? CookieSendingTask)?.cookies {
			let fields = HTTPCookie.requestHeaderFields(with: cookies)
			for (key, value) in fields {
				request.addValue(value, forHTTPHeaderField: key)
			}
		}
		
		return request
	}

	var httpMethod: String {
		if let custom = self.wrappedTask as? CustomHTTPMethodTask { return custom.customHTTPMethod }
		
		if self.wrappedTask is ServerPOSTTask { return "POST" }
		if self.wrappedTask is ServerPUTTask { return "PUT" }
		if self.wrappedTask is ServerPATCHTask { return "PATCH" }
		if self.wrappedTask is ServerDELETETask { return "DELETE" }
		return "GET"
	}
}
