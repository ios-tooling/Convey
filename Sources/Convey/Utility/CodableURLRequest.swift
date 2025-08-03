//
//  CodableURLRequest.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/21/25.
//

import SwiftUI

public struct CodableURLRequest: Codable, Sendable, CustomStringConvertible {
	public let url: URL?
	public let cachePolicy: CachePolicy?
	public let timeoutInterval: TimeInterval?
	public let mainDocumentURL: URL?
	public let networkServiceType: NetworkServiceType?
	public let allowsCellularAccess: Bool
	public let allowsExpensiveNetworkAccess: Bool
	public let allowsConstrainedNetworkAccess: Bool
	public let assumesHTTP3Capable: Bool?
	public let attribution: Attribution?
	public let requiresDNSSECValidation: Bool?
	public let allowsPersistentDNS: Bool?
	public let httpMethod: String?
	public let allHTTPHeaderFields: [String: String]?
	public let httpBody: Data?
	public let httpShouldHandleCookies: Bool?
	public let cookiePartitionIdentifier: String?
	public let httpShouldUsePipelining: Bool
	
	public var request: URLRequest? {
		guard let url else { return nil }
		var request = URLRequest(url: url)
		if let cachePolicy, let policy = URLRequest.CachePolicy(rawValue: cachePolicy.rawValue) { request.cachePolicy = policy }
		if let timeoutInterval { request.timeoutInterval = timeoutInterval }
		request.mainDocumentURL = mainDocumentURL
		if let networkServiceType, let type = URLRequest.NetworkServiceType(rawValue: networkServiceType.rawValue) { request.networkServiceType = type }
		request.allowsCellularAccess = allowsCellularAccess
		request.allowsExpensiveNetworkAccess = allowsExpensiveNetworkAccess
		request.allowsConstrainedNetworkAccess = allowsConstrainedNetworkAccess
		if #available(iOS 14.5, macOS 13, watchOS 9, *), let assumesHTTP3Capable {
			request.assumesHTTP3Capable = assumesHTTP3Capable
		}
		if #available(iOS 15, macOS 13, watchOS 9, *), let attribution, let new = URLRequest.Attribution(rawValue: attribution.rawValue) { request.attribution = new }
		if #available(iOS 16.1, macOS 14, watchOS 9, *), let requiresDNSSECValidation { request.requiresDNSSECValidation = requiresDNSSECValidation }
		if let httpShouldHandleCookies { request.httpShouldHandleCookies = httpShouldHandleCookies }
		
		request.httpMethod = httpMethod
		request.httpBody = httpBody
		if #available(iOS 18.2, macOS 15, watchOS 11, *) {
			request.cookiePartitionIdentifier = cookiePartitionIdentifier
		}
		request.httpShouldUsePipelining = httpShouldUsePipelining
		
		return request
	}
	
	@available(iOS 15, *)
	public var attributedDescription: AttributedString {
		var result = AttributedString(methodAndURL + "\n")
		let standardFont = Font.system(size: 10).monospaced()
		result.font = standardFont
		
		
		if let timeoutInterval { result += AttributedString("Timeout: \(timeoutInterval)\n") }
		if let main = mainDocumentURL {
			result += AttributedString("Main Document URL: \(main.absoluteString)\n")
		}
		if let httpShouldHandleCookies { result += AttributedString("Handles cookies: \(httpShouldHandleCookies)\n") }
		
		if let headers = allHTTPHeaderFields {
			result += AttributedString("Headers\n")
			for key in headers.keys.sorted() {
				var line = AttributedString("\t• \(key): ")
				line.font = standardFont
				line.foregroundColor = .primary.opacity(0.66)
				
				var value = AttributedString("\(headers[key] ?? "")")
				value.font = standardFont.bold()

				result += line + value + AttributedString("\n")
			}
		}
		
		if let data = httpBody, let string = data.reportedData(limit: 500) {
			result += AttributedString("Body:\n")
			var body = AttributedString("\n" + string)
			body.font = standardFont
			result += body
		}

		return result
	}
	
	var methodAndURL: String { "[\(httpMethod ?? "MISSING")] \(url?.absoluteString ?? "NO URL")" }
	
	public var description: String {
		var result = methodAndURL + "\n"
		
		if let timeoutInterval { result += "Timeout: \(timeoutInterval)\n" }
		if let main = mainDocumentURL {
			result += "Main Document URL: \(main.absoluteString)\n"
		}
		if let httpShouldHandleCookies { result += "Handles cookies: \(httpShouldHandleCookies)\n" }
		
		if let headers = allHTTPHeaderFields {
			result += "Headers\n"
			for key in headers.keys.sorted() {
				result += "\t• \(key): \(headers[key] ?? "")\n"
			}
		}
		
		if let data = httpBody, let string = data.reportedData(limit: 500) {
			result += "Body:\n"
			result += "\n" + string
		}
		
		return result
	}
	
	public enum Attribution : UInt, Sendable, Codable { case developer, user
		@available(iOS 15, *)
		init?(_ attribution: URLRequest.Attribution?) {
			guard let attr = Attribution(rawValue: attribution?.rawValue ?? 65000) else { return nil }
			self = attr
		}
	}
	public enum NetworkServiceType : UInt, Sendable, Codable { case `default` = 0, voip = 1, video = 2, background = 3, voice = 4, responsiveData = 6, avStreaming = 8, responsiveAV = 9, callSignaling = 11
		init?(_ type: URLRequest.NetworkServiceType?) {
			guard let networkType = NetworkServiceType(rawValue: type?.rawValue ?? 65000) else { return nil }
			self = networkType
		}
	}
	public enum CachePolicy : UInt, Sendable, Codable { case useProtocolCachePolicy = 0, reloadIgnoringLocalCacheData = 1, reloadIgnoringLocalAndRemoteCacheData = 4, returnCacheDataElseLoad = 2, returnCacheDataDontLoad = 3, reloadRevalidatingCacheData = 5
		init?(_ policy: URLRequest.CachePolicy?) {
			guard let cachePolicy = CachePolicy(rawValue: policy?.rawValue ?? 65000) else { return nil }
			self = cachePolicy
		}
	}
	
	public init(_ request: URLRequest) {
		url = request.url
		cachePolicy = .init(request.cachePolicy)
		timeoutInterval = request.timeoutInterval
		mainDocumentURL = request.mainDocumentURL
		networkServiceType = .init(request.networkServiceType)
		allowsCellularAccess = request.allowsCellularAccess
		allowsExpensiveNetworkAccess = request.allowsExpensiveNetworkAccess
		allowsConstrainedNetworkAccess = request.allowsConstrainedNetworkAccess

		if #available(iOS 14.5, *) {
			assumesHTTP3Capable = request.assumesHTTP3Capable
		} else {
			assumesHTTP3Capable = nil
		}
		
		if #available(iOS 15, *) {
			attribution = .init(request.attribution)
		} else {
			attribution = nil
		}

		if #available(iOS 16.1, *) {
			requiresDNSSECValidation = request.requiresDNSSECValidation
		} else {
			requiresDNSSECValidation = nil
		}

		if #available(iOS 18.0, *) {
			allowsPersistentDNS = request.allowsPersistentDNS
		} else {
			allowsPersistentDNS = nil
		}

		httpMethod = request.httpMethod
		allHTTPHeaderFields = request.allHTTPHeaderFields
		httpBody = request.httpBody
		httpShouldHandleCookies = request.httpShouldHandleCookies
		if #available(iOS 18.2, *) {
			cookiePartitionIdentifier = request.cookiePartitionIdentifier
		} else {
			cookiePartitionIdentifier = nil
		}
		httpShouldUsePipelining = request.httpShouldUsePipelining
	}
}
