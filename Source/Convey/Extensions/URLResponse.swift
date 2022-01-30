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
}
