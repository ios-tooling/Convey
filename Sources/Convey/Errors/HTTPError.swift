//
//  HTTPError.swift
//  Convey
//
//  Created by Ben Gottlieb on 10/2/25.
//

import Foundation

public protocol HTTPErrorType: Sendable, LocalizedError {
	var statusCode: Int { get }
	var data: Data? { get }
	var rawDescription: String? { get }
}

struct HTTPError {
	struct UnknownError: HTTPErrorType {
		let statusCode: Int
		let data: Data?
		let rawDescription: String? = "Unknown error"
		let underlyingError: Error?
	}
	
	static func withStatusCode(_ code: Int, data: Data?, throwingStatusCategories: [Int], underlyingError: Error?) -> (any HTTPErrorType)? {
		let statusFamily = (code / 100) * 100
		if !throwingStatusCategories.contains(statusFamily) { return nil }
		
		switch statusFamily {
		case 200: return Optional<UnknownError>.none
			
		case 400: return ClientError(statusCode: code, data: data, error: underlyingError)
		case 500: return ServerError(statusCode: code, data: data, error: underlyingError)
			
		default: break
		}
		
		return UnknownError(statusCode: code, data: data, underlyingError: underlyingError)
	}
}

extension HTTPErrorType {
	public var errorDescription: String? {
		if let data, let string = String(data: data, encoding: .utf8) {
			guard let rawDescription else { return string }
			
			return rawDescription + " (\(statusCode))\n" + string
		}
		
		if let rawDescription { return rawDescription + " (\(statusCode))" }
		return "HTTP Error (\(statusCode))"
	}
}

