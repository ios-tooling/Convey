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
	public private(set) var allHeaderFields: [String: String]?

	mutating func redact(headersNamed names: Set<String>) {
		guard let headers = allHeaderFields, !names.isEmpty else { return }
		let lowercased = Set(names.map { $0.lowercased() })

		allHeaderFields = headers.reduce(into: [:]) { result, header in
			result[header.key] = lowercased.contains(header.key.lowercased()) ? Constants.redactedValue : header.value
		}
	}
	
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
