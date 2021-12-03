//
//  SimpleTasks.swift
//  
//
//  Created by Ben Gottlieb on 12/3/21.
//

import Foundation
import Combine

public struct SimplePOSTTask: ServerPOSTTask, CustomURLRequestTask, DataUploadingTask {
	public var path = ""
	
	let payloadString: String
	let url: URL
	public var uploadData: Data? { payloadString.data(using: .utf8) }
	
	public var customURLRequest: AnyPublisher<URLRequest?, Error> {
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.httpBody = payloadString.data(using: .utf8)
		return Just(request).setFailureType(to: Error.self).eraseToAnyPublisher()
	}
	
	public init(url: URL, payload: String) {
		self.url = url
		self.payloadString = payload
	}
}

public struct SimpleGETTask: ServerGETTask, CustomURLRequestTask {
	public var path = ""
	
	let url: URL
	
	public var customURLRequest: AnyPublisher<URLRequest?, Error> {
		Just(URLRequest(url: url)).setFailureType(to: Error.self).eraseToAnyPublisher()
	}
	
	public init(url: URL) {
		self.url = url
	}
}
