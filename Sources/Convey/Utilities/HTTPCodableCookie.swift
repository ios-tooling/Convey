//
//  HTTPCodableCookie.swift
//
//
//  Created by Ben Gottlieb on 8/15/23.
//

import Foundation

extension Array where Element == HTTPCodableCookie {
	public var cookies: [HTTPCookie] {
		compactMap { $0.cookie }
	}
}

extension Array where Element == HTTPCookie {
	public var codableCookies: [HTTPCodableCookie] {
		compactMap { .init($0) }
	}
}

public struct HTTPCodableCookie: Codable, Equatable, Sendable {
	var properties: [String: String]
	var expiresDate: Date?
	var version = 0
	var isSecure = false
	var isHTTPOnly = false
	var commentURL: URL?
	var portList: [Int]?
	
	init(_ cookie: HTTPCookie) {
		var props: [String: String] = [:]
		
		for (key, value) in cookie.properties ?? [:] {
			if let string = value as? String {
				props[key.rawValue] = string
			}
		}
		
		expiresDate = cookie.expiresDate
		version = cookie.version
		isSecure = cookie.isSecure
		isHTTPOnly = cookie.isHTTPOnly
		commentURL = cookie.commentURL
		portList = cookie.portList?.map { $0.intValue }
		
		properties = props
	}
	
	var cookieProperties: [HTTPCookiePropertyKey: Any] {
		var results: [HTTPCookiePropertyKey: Any] = [:]
		
		for (key, value) in properties {
			results[HTTPCookiePropertyKey(key)] = value
		}
		
		if let expiresDate { results[.expires] = expiresDate }
		results[.version] = version
		results[.secure] = isSecure
		results[.commentURL] = commentURL

		return results
	}
	
	var cookie: HTTPCookie? {
		HTTPCookie(properties: cookieProperties)
	}
}
