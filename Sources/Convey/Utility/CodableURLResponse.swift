//
//  CodableURLResponse.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/21/25.
//

import Foundation

public struct CodableURLResponse: Codable, Sendable, CustomStringConvertible {
	public let url: URL?
	public let mimeType: String?
	public let expectedContentLength: Int64
	public let textEncodingName: String?
	public let suggestedFilename: String?
	public let statusCode: Int?
	public let allHeaderFields: [String: String]?
	
	public var response: URLResponse? {
		guard let url, let statusCode else { return nil }
		let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: allHeaderFields)
		
		return response
	}
	
	public var description: String {
		""
	}
	
	public init(_ response: URLResponse) {
		url = response.url
		mimeType = response.mimeType
		expectedContentLength = response.expectedContentLength
		textEncodingName = response.textEncodingName
		suggestedFilename = response.suggestedFilename
		statusCode = (response as? HTTPURLResponse)?.statusCode
		allHeaderFields = (response as? HTTPURLResponse)?.allHeaderFields as? [String: String]
	}
}
