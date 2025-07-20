//
//  SimpleGETTask.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/19/25.
//

import Foundation

public struct SimpleGETTask: DataDownloadingTask, Sendable {
	public var url: URL
	public var request: URLRequest
	
	public func buildRequest() async throws -> URLRequest { request }
	
	public init(request: URLRequest) {
		self.request = request
		self.url = request.url ?? URL(string: "about:blank")!
	}
	
	public init(url: URL) {
		self.request = URLRequest(url: url)
		self.url = url
	}
}
