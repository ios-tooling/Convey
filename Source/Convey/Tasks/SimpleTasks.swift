//
//  SimpleTasks.swift
//  
//
//  Created by Ben Gottlieb on 12/3/21.
//

import Foundation
import Combine

public struct SimplePOSTTask: ServerPOSTTask, CustomAsyncURLRequestTask, DataUploadingTask {
	public var path = ""
	
	let payloadString: String
	public let url: URL
	public var dataToUpload: Data? { payloadString.data(using: .utf8) }
	
	public var customURLRequest: URLRequest {
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.httpBody = payloadString.data(using: .utf8)
		return request
	}
	
	public init(url: URL, payload: String) {
		self.url = url
		self.payloadString = payload
	}
}

public struct SimpleGETTask: ServerGETTask, CustomAsyncURLRequestTask {
	public var path = ""
	
	public var url: URL
	public var request: URLRequest
	
	public var customURLRequest: URLRequest {
		request
	}
	
	public init(request: URLRequest) {
		self.request = request
		self.url = request.url ?? URL(string: "about:blank")!
	}
	
	public init(url: URL) {
		self.request = URLRequest(url: url)
		self.url = url
	}
}
