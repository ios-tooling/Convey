//
//  CodableURLRequest.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/21/25.
//

import Foundation

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
	
	public var description: String {
		var result = ""
		
		result += "\(httpMethod ?? "[MISSING]") \(url?.absoluteString ?? "NO URL")\n"
		if let timeoutInterval { result += "Timeout: \(timeoutInterval)\n" }
		if let main = mainDocumentURL {
			result += "Main Document URL: \(main.absoluteString)\n"
		}
		if let httpShouldHandleCookies { result += "Handles cookies: \(httpShouldHandleCookies)\n" }
		
		if let headers = allHTTPHeaderFields {
			result += "Headers\n"
			for (header, value) in headers {
				result += "\t\(header): \(value)\n"
			}
		}
		
		if let data = httpBody, let string = String(data: data, encoding: .utf8) {
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
