//
//  TaskConfiguration.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/19/25.
//

import Foundation

public struct TaskConfiguration: Sendable {
	public var timeout: TimeInterval?
	public var headers: Headers?
	public var cookies: [HTTPCookie]?
	public var localSourceURL: URL?
	public var echoStyle: TaskEchoStyle?
	public var gzip: Bool?
	public var queryParameters: (any TaskQueryParameters)?
	
	public static let `default` = TaskConfiguration(gzip: true)
	
	public init(timeout: TimeInterval? = nil, headers: Headers? = nil, cookies: [HTTPCookie]? = nil, localSourceURL: URL? = nil, echoStyle: TaskEchoStyle? = nil, gzip: Bool? = nil, queryParameters: (any TaskQueryParameters)? = nil) {
		
		self.timeout = timeout
		self.headers = headers
		self.cookies = cookies
		self.localSourceURL = localSourceURL
		self.echoStyle = echoStyle
		self.gzip = gzip
		self.queryParameters = queryParameters
	}
}

extension TaskConfiguration {
	func merged(with other: Self) -> Self {
		var result = self
		
		if let timeout = other.timeout { result.timeout = timeout }
		if let headers = other.headers { result.headers = headers + (self.headers ?? []) }
		if let cookies = other.cookies { result.cookies = cookies + (self.cookies ?? []) }
		if let sourceURL = other.localSourceURL { result.localSourceURL = sourceURL }
		if let echoStyle = other.echoStyle { result.echoStyle = echoStyle }
		if let gzip = other.gzip { result.gzip = gzip }
		result.queryParameters = queryParameters + other.queryParameters

		return result
	}
}
