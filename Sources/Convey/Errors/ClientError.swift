//
//  ClientError.swift
//  Convey
//
//  Created by Ben Gottlieb on 10/2/25.
//

import Foundation

extension HTTPError {
	enum ClientError: HTTPErrorType {
		case badRequest(Data?, Error?)
		case unauthorized(Data?, Error?)
		case paymentRequired(Data?, Error?)
		case forbidden(Data?, Error?)
		case notFound(Data?, Error?)
		case methodNotAllowed(Data?, Error?)
		case notAcceptable(Data?, Error?)
		case proxyAuthenticationRequired(Data?, Error?)
		case requestTimeout(Data?, Error?)
		case conflict(Data?, Error?)
		case gone(Data?, Error?)
		case lengthRequired(Data?, Error?)
		case preconditionFailed(Data?, Error?)
		case contentTooLarge(Data?, Error?)
		case uriTooLong(Data?, Error?)
		case unsupportedMediaType(Data?, Error?)
		case rangeNotSatisfiable(Data?, Error?)
		case expectationFailed(Data?, Error?)
		case imATeapot(Data?, Error?)
		case misdirectedRequest(Data?, Error?)
		case unprocessableContent(Data?, Error?)
		case locked(Data?, Error?)
		case failedDependency(Data?, Error?)
		case tooEarly(Data?, Error?)
		case upgradeRequired(Data?, Error?)
		case preconditionRequired(Data?, Error?)
		case tooManyRequests(Data?, Error?)
		case requestHeaderFieldsTooLarge(Data?, Error?)
		case unavailableForLegalReasons(Data?, Error?)

		init?(statusCode: Int, data: Data?, error: Error?) {
			switch statusCode {
			case 400: self = .badRequest(data, error)
			case 401: self = .unauthorized(data, error)
			case 402: self = .paymentRequired(data, error)
			case 403: self = .forbidden(data, error)
			case 404: self = .notFound(data, error)
			case 405: self = .methodNotAllowed(data, error)
			case 406: self = .notAcceptable(data, error)
			case 407: self = .proxyAuthenticationRequired(data, error)
			case 408: self = .requestTimeout(data, error)
			case 409: self = .conflict(data, error)
			case 410: self = .gone(data, error)
			case 411: self = .lengthRequired(data, error)
			case 412: self = .preconditionFailed(data, error)
			case 413: self = .contentTooLarge(data, error)
			case 414: self = .uriTooLong(data, error)
			case 415: self = .unsupportedMediaType(data, error)
			case 416: self = .rangeNotSatisfiable(data, error)
			case 417: self = .expectationFailed(data, error)
			case 418: self = .imATeapot(data, error)
			case 421: self = .misdirectedRequest(data, error)
			case 422: self = .unprocessableContent(data, error)
			case 423: self = .locked(data, error)
			case 424: self = .failedDependency(data, error)
			case 425: self = .tooEarly(data, error)
			case 426: self = .upgradeRequired(data, error)
			case 428: self = .preconditionRequired(data, error)
			case 429: self = .tooManyRequests(data, error)
			case 431: self = .requestHeaderFieldsTooLarge(data, error)
			case 451: self = .unavailableForLegalReasons(data, error)
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
			case .badRequest(let data, _): data
			case .unauthorized(let data, _): data
			case .paymentRequired(let data, _): data
			case .forbidden(let data, _): data
			case .notFound(let data, _): data
			case .methodNotAllowed(let data, _): data
			case .notAcceptable(let data, _): data
			case .proxyAuthenticationRequired(let data, _): data
			case .requestTimeout(let data, _): data
			case .conflict(let data, _): data
			case .gone(let data, _): data
			case .lengthRequired(let data, _): data
			case .preconditionFailed(let data, _): data
			case .contentTooLarge(let data, _): data
			case .uriTooLong(let data, _): data
			case .unsupportedMediaType(let data, _): data
			case .rangeNotSatisfiable(let data, _): data
			case .expectationFailed(let data, _): data
			case .imATeapot(let data, _): data
			case .misdirectedRequest(let data, _): data
			case .unprocessableContent(let data, _): data
			case .locked(let data, _): data
			case .failedDependency(let data, _): data
			case .tooEarly(let data, _): data
			case .upgradeRequired(let data, _): data
			case .preconditionRequired(let data, _): data
			case .tooManyRequests(let data, _): data
			case .requestHeaderFieldsTooLarge(let data, _): data
			case .unavailableForLegalReasons(let data, _): data
			}
		}

		public var rawDescription: String? {
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
