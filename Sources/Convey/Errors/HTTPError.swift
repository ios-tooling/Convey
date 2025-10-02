//
//  File.swift
//  Convey
//
//  Created by Ben Gottlieb on 10/2/25.
//

import Foundation

public protocol HTTPErrorType: Sendable, LocalizedError {
	var statusCode: Int { get }
	var data: Data? { get }
}

struct HTTPError {
	struct UnknownError: HTTPErrorType {
		let statusCode: Int
		let data: Data?
	}
	
	static func withStatusCode(_ code: Int, data: Data?, throwingStatusCategories: [Int]) -> (any HTTPErrorType)? {
		let statusFamily = (code / 100) * 100
		if !throwingStatusCategories.contains(statusFamily) { return nil }
			
		switch statusFamily {
		case 200: return Optional<UnknownError>.none

		case 400: return ClientError(statusCode: code, data: data)
		case 500: return ServerError(statusCode: code, data: data)

		default: break
		}

		return UnknownError(statusCode: code, data: data)
	}
	
}

