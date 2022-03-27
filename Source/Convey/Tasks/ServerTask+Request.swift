//
//  ServerTask+Request.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 9/11/21.
//

import Foundation
import Combine

public extension ServerTask {
	func buildRequest() -> AnyPublisher<URLRequest, Error> {
		if let custom = self as? CustomURLRequestTask {
			return custom.customURLRequest
				.map { req in
					req ?? defaultRequest()
				}
				.eraseToAnyPublisher()
		}
			
		let request = defaultRequest()
		return Just(request).setFailureType(to: Error.self).eraseToAnyPublisher()
	}
	
	func defaultRequest() -> URLRequest {
		var request = URLRequest(url: url)
		
		request.httpMethod = httpMethod
		if let dataProvider = self as? DataUploadingTask {
			if request.httpMethod == "GET" { request.httpMethod = "POST" }
			request.httpBody = dataProvider.dataToUpload
		}
		request.allHTTPHeaderFields = server.standardHeaders()
		if let tagged = self as? TaggedTask {
			request.addValue(tagged.requestTag, forHTTPHeaderField: ServerConstants.Headers.tag)
		}
		
		if let additionalHeaders = (self as? CustomHTTPHeaders)?.customHTTPHeaders {
			for (value, header) in additionalHeaders {
				request.addValue(value, forHTTPHeaderField: header)
			}
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
