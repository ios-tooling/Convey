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
	
	func defaultRequest() -> URLRequest {
		var request = URLRequest(url: url)
		
		request.httpMethod = httpMethod
		if let dataProvider = self as? DataUploadingTask {
			if request.httpMethod == "GET" { request.httpMethod = "POST" }
			request.httpBody = dataProvider.dataToUpload
			if request.allHTTPHeaderFields?[ServerConstants.Headers.contentType] == nil {
				if self is JSONPayloadTask {
					request.addValue("application/json", forHTTPHeaderField: ServerConstants.Headers.contentType)
				} else {
					request.addValue("text/plain", forHTTPHeaderField: ServerConstants.Headers.contentType)
				}
			}
		}
		request.allHTTPHeaderFields = server.standardHeaders(for: self)
		if let tagged = self as? TaggedTask {
			request.addValue(tagged.requestTag, forHTTPHeaderField: ServerConstants.Headers.tag)
		}
		
		if let additionalHeaders = (self as? CustomHTTPHeaders)?.customHTTPHeaders {
			for (value, header) in additionalHeaders {
				request.addValue(value, forHTTPHeaderField: header)
			}
		}
		
		if self is ETagCachedTask, let etag = cachedEtag, DataCache.instance.hasCachedValue(for: url) {
			request.addValue(etag, forHTTPHeaderField: "If-None-Match")
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
