//
//  ServerError.swift
//  Convey
//
//  Created by Ben Gottlieb on 10/2/25.
//

import Foundation

extension HTTPError {
	enum ServerError: HTTPErrorType {
		case internalServer(Data?)
		case notImplemented(Data?)
		case badGateway(Data?)
		case serviceUnavailable(Data?)
		case gatewayTimeout(Data?)
		case versionNotSupported(Data?)
		case variantAlsoNegotiates(Data?)
		case insufficientStorage(Data?)
		case loopDetected(Data?)
		case notExtended(Data?)
		case networkAuthenticationRequired(Data?)
		
		init?(statusCode: Int, data: Data?) {
			switch statusCode {
			case 500: self = .internalServer(data)
			case 501: self = .notImplemented(data)
			case 502: self = .badGateway(data)
			case 503: self = .serviceUnavailable(data)
			case 504: self = .gatewayTimeout(data)
			case 505: self = .versionNotSupported(data)
			case 506: self = .variantAlsoNegotiates(data)
			case 507: self = .insufficientStorage(data)
			case 508: self = .loopDetected(data)
			case 510: self = .notExtended(data)
			case 511: self = .networkAuthenticationRequired(data)
			default: return nil
			}
		}
		
		public var statusCode: Int {
			switch self {
			case .internalServer: 500
			case .notImplemented: 501
			case .badGateway: 502
			case .serviceUnavailable: 503
			case .gatewayTimeout: 504
			case .versionNotSupported: 505
			case .variantAlsoNegotiates: 506
			case .insufficientStorage: 507
			case .loopDetected: 508
			case .notExtended: 510
			case .networkAuthenticationRequired: 511
			}
		}
		
		public var data: Data? {
			switch self {
			case .internalServer(let data): data
			case .notImplemented(let data): data
			case .badGateway(let data): data
			case .serviceUnavailable(let data): data
			case .gatewayTimeout(let data): data
			case .versionNotSupported(let data): data
			case .variantAlsoNegotiates(let data): data
			case .insufficientStorage(let data): data
			case .loopDetected(let data): data
			case .notExtended(let data): data
			case .networkAuthenticationRequired(let data): data
			}
		}

		public var errorDescription: String? {
			if let data, let string = String(data: data, encoding: .utf8) {
				guard let rawDescription else { return string }
				
				return rawDescription + "\n" + string
			}
			
			return rawDescription
		}
		
		public var rawDescription: String? {
			switch self {
			case .internalServer: "Internal Server Error"
			case .notImplemented: "Not Implemented"
			case .badGateway: "Bad Gateway"
			case .serviceUnavailable: "Service Unavailable"
			case .gatewayTimeout: "Gateway Timeout"
			case .versionNotSupported: "HTTP Version Not Supported"
			case .variantAlsoNegotiates: "Variant Also Negotiates"
			case .insufficientStorage: "Insufficient Storage"
			case .loopDetected: "Loop Detected"
			case .notExtended: "Not Extended"
			case .networkAuthenticationRequired: "Network Authentication Required"
			}
		}
	}
	
}
