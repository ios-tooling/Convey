//
//  GetImageTask.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/20/25.
//

import Foundation

public struct GetImageTask: DataDownloadingTask {
	public var url: URL
	public var request: URLRequest
	
	public init(request: URLRequest) {
		self.request = request
		self.url = request.url ?? URL(string: "about:blank")!
	}
	
	public init(url: URL) {
		self.request = URLRequest(url: url)
		self.url = url
	}
}
