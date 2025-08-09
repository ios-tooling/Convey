//
//  Constants.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/19/25.
//

import Foundation

public struct Constants {
	public static let applicationJson = "application/json"
	public struct Headers {
		public static let contentType = "Content-Type"
		public static let accept = "Accept"
		public static let contentEncoding = "Content-Encoding"
		public static let contentLength = "Content-Length"
		public static let acceptEncoding = "Accept-Encoding"
		public static let tag = "X-Convey-RequestTag"
		public static let userAgent = "User-Agent"
		public static let ifNoneMatch = "If-None-Match"
	}
}
