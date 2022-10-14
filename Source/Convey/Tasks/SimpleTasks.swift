//
//  SimpleTasks.swift
//  
//
//  Created by Ben Gottlieb on 12/3/21.
//

import Foundation
import Combine

public struct SimpleMIMETask: ServerPOSTTask, MIMEUploadingTask {
	public var path = ""
	public let url: URL
	public let base64EncodeBody = true
	public let mimeFields: [MIMEMessageComponent]?
	public let mimeBoundary: String
	
	public init(url: URL, components: [MIMEMessageComponent], boundary: String = .sampleMIMEBoundary) {
		self.url = url
		self.mimeFields = components
		self.mimeBoundary = boundary
	}
}

public struct SimplePOSTTask: ServerPOSTTask, CustomURLRequestTask, DataUploadingTask {
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

public struct SimpleGETTask: ServerGETTask, CustomURLRequestTask {
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
