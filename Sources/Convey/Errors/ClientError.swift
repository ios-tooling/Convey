//
//  ClientError.swift
//  Convey
//
//  Created by Ben Gottlieb on 10/2/25.
//

import Foundation

extension HTTPError {
	enum ClientError: HTTPErrorType {
		case badRequest(Data?)
		case unauthorized(Data?)
		case paymentRequired(Data?)
		case forbidden(Data?)
		case notFound(Data?)
		case methodNotAllowed(Data?)
		case notAcceptable(Data?)
		case proxyAuthenticationRequired(Data?)
		case requestTimeout(Data?)
		case conflict(Data?)
		case gone(Data?)
		case lengthRequired(Data?)
		case preconditionFailed(Data?)
		case contentTooLarge(Data?)
		case uriTooLong(Data?)
		case unsupportedMediaType(Data?)
		case rangeNotSatisfiable(Data?)
		case expectationFailed(Data?)
		case imATeapot(Data?)
		case misdirectedRequest(Data?)
		case unprocessableContent(Data?)
		case locked(Data?)
		case failedDependency(Data?)
		case tooEarly(Data?)
		case upgradeRequired(Data?)
		case preconditionRequired(Data?)
		case tooManyRequests(Data?)
		case requestHeaderFieldsTooLarge(Data?)
		case unavailableForLegalReasons(Data?)

		init?(statusCode: Int, data: Data?) {
			switch statusCode {
			case 400: self = .badRequest(data)
			case 401: self = .unauthorized(data)
			case 402: self = .paymentRequired(data)
			case 403: self = .forbidden(data)
			case 404: self = .notFound(data)
			case 405: self = .methodNotAllowed(data)
			case 406: self = .notAcceptable(data)
			case 407: self = .proxyAuthenticationRequired(data)
			case 408: self = .requestTimeout(data)
			case 409: self = .conflict(data)
			case 410: self = .gone(data)
			case 411: self = .lengthRequired(data)
			case 412: self = .preconditionFailed(data)
			case 413: self = .contentTooLarge(data)
			case 414: self = .uriTooLong(data)
			case 415: self = .unsupportedMediaType(data)
			case 416: self = .rangeNotSatisfiable(data)
			case 417: self = .expectationFailed(data)
			case 418: self = .imATeapot(data)
			case 421: self = .misdirectedRequest(data)
			case 422: self = .unprocessableContent(data)
			case 423: self = .locked(data)
			case 424: self = .failedDependency(data)
			case 425: self = .tooEarly(data)
			case 426: self = .upgradeRequired(data)
			case 428: self = .preconditionRequired(data)
			case 429: self = .tooManyRequests(data)
			case 431: self = .requestHeaderFieldsTooLarge(data)
			case 451: self = .unavailableForLegalReasons(data)
			default: return nil
			}
		}

		public var statusCode: Int {
			switch self {
			case .badRequest: 400
			case .unauthorized: 401
			case .paymentRequired: 402
			case .forbidden: 403
			case .notFound: 404
			case .methodNotAllowed: 405
			case .notAcceptable: 406
			case .proxyAuthenticationRequired: 407
			case .requestTimeout: 408
			case .conflict: 409
			case .gone: 410
			case .lengthRequired: 411
			case .preconditionFailed: 412
			case .contentTooLarge: 413
			case .uriTooLong: 414
			case .unsupportedMediaType: 415
			case .rangeNotSatisfiable: 416
			case .expectationFailed: 417
			case .imATeapot: 418
			case .misdirectedRequest: 421
			case .unprocessableContent: 422
			case .locked: 423
			case .failedDependency: 424
			case .tooEarly: 425
			case .upgradeRequired: 426
			case .preconditionRequired: 428
			case .tooManyRequests: 429
			case .requestHeaderFieldsTooLarge: 431
			case .unavailableForLegalReasons: 451
			}
		}

		public var data: Data? {
			switch self {
			case .badRequest(let data): data
			case .unauthorized(let data): data
			case .paymentRequired(let data): data
			case .forbidden(let data): data
			case .notFound(let data): data
			case .methodNotAllowed(let data): data
			case .notAcceptable(let data): data
			case .proxyAuthenticationRequired(let data): data
			case .requestTimeout(let data): data
			case .conflict(let data): data
			case .gone(let data): data
			case .lengthRequired(let data): data
			case .preconditionFailed(let data): data
			case .contentTooLarge(let data): data
			case .uriTooLong(let data): data
			case .unsupportedMediaType(let data): data
			case .rangeNotSatisfiable(let data): data
			case .expectationFailed(let data): data
			case .imATeapot(let data): data
			case .misdirectedRequest(let data): data
			case .unprocessableContent(let data): data
			case .locked(let data): data
			case .failedDependency(let data): data
			case .tooEarly(let data): data
			case .upgradeRequired(let data): data
			case .preconditionRequired(let data): data
			case .tooManyRequests(let data): data
			case .requestHeaderFieldsTooLarge(let data): data
			case .unavailableForLegalReasons(let data): data
			}
		}

		public var errorDescription: String? {
			switch self {
			case .badRequest: "Bad Request"
			case .unauthorized: "Unauthorized"
			case .paymentRequired: "Payment Required"
			case .forbidden: "Forbidden"
			case .notFound: "Not Found"
			case .methodNotAllowed: "Method Not Allowed"
			case .notAcceptable: "Not Acceptable"
			case .proxyAuthenticationRequired: "Proxy Authentication Required"
			case .requestTimeout: "Request Timeout"
			case .conflict: "Conflict"
			case .gone: "Gone"
			case .lengthRequired: "Length Required"
			case .preconditionFailed: "Precondition Failed"
			case .contentTooLarge: "Content Too Large"
			case .uriTooLong: "URI Too Long"
			case .unsupportedMediaType: "Unsupported Media Type"
			case .rangeNotSatisfiable: "Range Not Satisfiable"
			case .expectationFailed: "Expectation Failed"
			case .imATeapot: "I'm a teapot"
			case .misdirectedRequest: "Misdirected Request"
			case .unprocessableContent: "Unprocessable Content"
			case .locked: "Locked"
			case .failedDependency: "Failed Dependency"
			case .tooEarly: "Too Early"
			case .upgradeRequired: "Upgrade Required"
			case .preconditionRequired: "Precondition Required"
			case .tooManyRequests: "Too Many Requests"
			case .requestHeaderFieldsTooLarge: "Request Header Fields Too Large"
			case .unavailableForLegalReasons: "Unavailable For Legal Reasons"
			}
		}
	}
}