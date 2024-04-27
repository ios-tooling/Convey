//
//  ServerTask+Protocols.swift
//
//
//  Created by Ben Gottlieb on 1/5/24.
//

import Foundation

public protocol AllowedOnExpensiveNetworkTask: ServerTask { }
public protocol AllowedOnConstrainedNetworkTask: ServerTask { }

public protocol ParameterizedTask: ServerTask {
	var parameters: TaskURLParameters? { get }
}

public protocol FileBackedTask: ServerTask {
	var fileURL: URL? { get }
}

public protocol CustomURLTask: ServerTask {
	var customURL: URL? { get }
}

public protocol TaggedTask: ServerTask {
	var requestTag: String { get }
}

public protocol CustomURLRequestTask: ServerTask {
	 var customURLRequest: URLRequest { get async throws }
}

public protocol RefreshableCachedTask: ServerTask { }

public protocol CookieSendingTask: ServerTask {
	var cookies: [HTTPCookie]? { get }
}

public protocol CustomTimeoutTask: ServerTask {
	var timeout: TimeInterval { get }
}

public protocol DataUploadingTask: ServerUploadingTask {
	var dataToUpload: Data? { get }
	var contentType: String? { get }
}

public protocol MIMEUploadingTask: DataUploadingTask {
	var mimeBoundary: String { get }
	var mimeFields: [MIMEMessageComponent]? { get }
	var base64EncodeBody: Bool { get }
}

public protocol FormURLEncodedUploadingTask: DataUploadingTask {
	var formFields: [String: any Sendable] { get }
}

public protocol ETagCachedTask: ServerGETTask { }
public protocol JSONPayloadTask: ServerTask { }
public protocol GZipEncodedUploadingTask: DataUploadingTask { }

public protocol JSONUploadingTask: DataUploadingTask, JSONPayloadTask {
	var jsonToUpload: [String: any Sendable]? { get }
}

public protocol CustomJSONEncoderTask: ServerTask {
	var jsonEncoder: JSONEncoder? { get }
}

public protocol CustomHTTPMethodTask: ServerTask {
	var customHTTPMethod: String { get }
}

public struct ConveyHeader: Codable, Hashable, CustomStringConvertible, Sendable {
	public let name: String
	public let value: String
	public var description: String {
		"\(name): \(value)"
	}
}
public protocol ConveyHeaders { }
extension [String: String]: ConveyHeaders { }
extension [ConveyHeader]: ConveyHeaders { }

public protocol CustomHTTPHeaders: ServerTask {
	var customHTTPHeaders: ConveyHeaders { get }
}

public protocol EchoingTask: ServerTask { }
public protocol ArchivingTask: ServerTask {
	var archiveURL: URL? { get }
}

public protocol ServerCacheableTask { }
public protocol ServerUploadingTask: ServerTask { }
public protocol ServerGETTask: ServerTask { }
public protocol ServerPUTTask: ServerUploadingTask { }
public protocol ServerPOSTTask: ServerUploadingTask { }
public protocol ServerPATCHTask: ServerUploadingTask { }
public protocol ServerDELETETask: ServerTask { }

public protocol ThreadedServerTask: ServerTask {
	var threadName: String? { get }
}

public protocol PreFlightTask: ServerTask {
	 func preFlight() async throws
}

public protocol PostFlightTask: ServerTask {
	 func postFlight() async throws
}

public protocol RetryableTask: ServerTask {
	func retryInterval(after error: Error, attemptNumber: Int) -> TimeInterval?
}

public protocol ServerSentEventTargetTask: ServerTask { }

public protocol PayloadDownloadingTask: ServerTask, PayloadDownloadable {
}

public protocol PayloadUploadingTask: DataUploadingTask, JSONPayloadTask {
	associatedtype UploadPayload: Encodable
	var uploadPayload: UploadPayload? { get }
}

