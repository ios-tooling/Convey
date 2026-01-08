//
//  ServerError.swift
//  Convey
//
//  Created by Ben Gottlieb on 10/2/25.
//

import Foundation

extension HTTPError {
	enum ServerError: HTTPErrorType {
		case internalServer(Data?, Error?)
		case notImplemented(Data?, Error?)
		case badGateway(Data?, Error?)
		case serviceUnavailable(Data?, Error?)
		case gatewayTimeout(Data?, Error?)
		case versionNotSupported(Data?, Error?)
		case variantAlsoNegotiates(Data?, Error?)
		case insufficientStorage(Data?, Error?)
		case loopDetected(Data?, Error?)
		case notExtended(Data?, Error?)
		case networkAuthenticationRequired(Data?, Error?)
		
		init?(statusCode: Int, data: Data?, error: Error?) {
			switch statusCode {
			case 500: self = .internalServer(data, error)
			case 501: self = .notImplemented(data, error)
			case 502: self = .badGateway(data, error)
			case 503: self = .serviceUnavailable(data, error)
			case 504: self = .gatewayTimeout(data, error)
			case 505: self = .versionNotSupported(data, error)
			case 506: self = .variantAlsoNegotiates(data, error)
			case 507: self = .insufficientStorage(data, error)
			case 508: self = .loopDetected(data, error)
			case 510: self = .notExtended(data, error)
			case 511: self = .networkAuthenticationRequired(data, error)
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
			case .internalServer(let data, _): data
			case .notImplemented(let data, _): data
			case .badGateway(let data, _): data
			case .serviceUnavailable(let data, _): data
			case .gatewayTimeout(let data, _): data
			case .versionNotSupported(let data, _): data
			case .variantAlsoNegotiates(let data, _): data
			case .insufficientStorage(let data, _): data
			case .loopDetected(let data, _): data
			case .notExtended(let data, _): data
			case .networkAuthenticationRequired(let data, _): data
			}
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
