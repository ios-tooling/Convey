//
//  TaskConfiguration.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/19/25.
//

import Foundation
import TagAlong

public struct TaskConfiguration: Sendable {
	enum CodingKeys: String, CodingKey { case timeout, headers, localSourceURL, echoStyle, gzip, throwingStatusCategories, tags }
	
	public var timeout: TimeInterval?
	public var headers: Headers?
	public var cookies: [HTTPCookie]?
	public var localSourceURL: URL?
	public var echoStyle: TaskEchoStyle?
	public var gzip: Bool?
	public var queryParameters: (any TaskQueryParameters)?
	public var throwingStatusCategories: [Int]?
	public var tags: TagCollection?

	public static let `default` = TaskConfiguration(gzip: true)
	
	public init(timeout: TimeInterval? = nil, headers: Headers? = nil, cookies: [HTTPCookie]? = nil, localSourceURL: URL? = nil, echoStyle: TaskEchoStyle? = nil, gzip: Bool? = nil, queryParameters: (any TaskQueryParameters)? = nil, throwingStatusCategories: [Int]? = nil, tags: TagCollection? = nil) {
		
		self.timeout = timeout
		self.headers = headers
		self.cookies = cookies
		self.localSourceURL = localSourceURL
		self.echoStyle = echoStyle
		self.gzip = gzip
		self.queryParameters = queryParameters
		self.throwingStatusCategories = throwingStatusCategories
		self.tags = tags
	}
}

extension TaskConfiguration: Codable {
	public func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		
		try container.encode(timeout, forKey: .timeout)
		if let dict = headers as? [String: String] {
			try container.encode(dict, forKey: .headers)
		} else if let array = headers as? [Header] {
			try container.encode(array, forKey: .headers)
		}
		try container.encode(localSourceURL, forKey: .localSourceURL)
		try container.encode(echoStyle, forKey: .echoStyle)
		try container.encode(gzip, forKey: .gzip)
		try container.encode(throwingStatusCategories, forKey: .throwingStatusCategories)
		if let tagArray = tags?.tags {
			try container.encode(tagArray, forKey: .tags)
		}
	}
	
	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		
		timeout = try container.decodeIfPresent(TimeInterval.self, forKey: .timeout)
		
		if let array = try? container.decode([Header].self, forKey: .headers) {
			headers = array
		} else if let dict = try? container.decode([String: String].self, forKey: .headers) {
			headers = dict
		}
		
		localSourceURL = try container.decodeIfPresent(URL.self, forKey: .localSourceURL)
		echoStyle = try container.decodeIfPresent(TaskEchoStyle.self, forKey: .echoStyle)
		gzip = try container.decodeIfPresent(Bool.self, forKey: .gzip)
		throwingStatusCategories = try container.decodeIfPresent([Int].self, forKey: .throwingStatusCategories)
		tags = try container.decodeIfPresent([Tag].self, forKey: .tags)
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
		if let tags = other.tags { result.tags = (self.tags?.tags ?? []) + tags.tags }
		result.throwingStatusCategories = (throwingStatusCategories ?? []) + (other.throwingStatusCategories ?? [])
		result.queryParameters = queryParameters + other.queryParameters

		return result
	}
}
