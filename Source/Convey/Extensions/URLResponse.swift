//
//  URLResponse.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 1/29/22.
//

import Foundation

extension URLResponse {
	convenience init(cachedFor url: URL, data: Data) {
		self.init(url: url, mimeType: nil, expectedContentLength: data.count, textEncodingName: nil)
	}
	
	var etag: String? {
		guard let headers = (self as? HTTPURLResponse)?.allHeaderFields else { return nil }
		for (key, value) in headers {
			if key.description.lowercased() == "etag", let str = value as? String { return str }
		}
		return nil
	}
	
	var didDownloadSuccessfully: Bool {
		guard let http = self as? HTTPURLResponse else { return false }
		
		return http.statusCode / 100 == 2 || http.statusCode == 304
	}
}
