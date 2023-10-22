//
//  ServerTask.swift
//  ServerTask
//
//  Created by Ben Gottlieb on 9/11/21.
//

import Combine
import Foundation

public typealias PreviewClosure = (ServerReturned) -> Void

public protocol ServerTask {
	var path: String { get }
	func postProcess(response: ServerReturned) async throws
	var httpMethod: String { get }
	var server: ConveyServer { get }
	var url: URL { get }
}

public protocol TaskURLParameters {
	var isEmpty: Bool { get }
}

extension Dictionary: TaskURLParameters where Key == String, Value == String { }
extension Array: TaskURLParameters where Element == URLQueryItem { }

public protocol ParameterizedTask: ServerTask {
	var parameters: TaskURLParameters? { get }
}

public protocol FileBackedTask: ServerTask {
	var fileURL: URL? { get }
}

public protocol CustomURLTask: ServerTask {
	var customURL: URL? { get }
}

public protocol CustomServerTask: ServerTask {
	var customServer: ConveyServer? { get }
}

public protocol TaggedTask: ServerTask {
	var requestTag: String { get }
}

public protocol Server: ServerTask {
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

public protocol DataUploadingTask: ServerTask {
	var dataToUpload: Data? { get }
	var contentType: String? { get }
}

public protocol MIMEUploadingTask: DataUploadingTask {
	var mimeBoundary: String { get }
	var mimeFields: [MIMEMessageComponent]? { get }
	var base64EncodeBody: Bool { get }
}

public protocol ETagCachedTask: ServerGETTask { }
public protocol JSONPayloadTask: ServerTask { }
public protocol GZipEncodedUploadingTask: DataUploadingTask { }

public protocol JSONUploadingTask: DataUploadingTask, JSONPayloadTask {
	var jsonToUpload: [String: Any]? { get }
}

public protocol CustomJSONEncoderTask: ServerTask {
	var jsonEncoder: JSONEncoder? { get }
}

public protocol CustomHTTPMethodTask: ServerTask {
	var customHTTPMethod: String { get }
}

public protocol CustomHTTPHeaders: ServerTask {
	var customHTTPHeaders: [String: String] { get }
}

public protocol EchoingTask: ServerTask { }

public protocol ServerCacheableTask { }
public protocol ServerGETTask: ServerTask { }
public protocol ServerPUTTask: ServerTask { }
public protocol ServerPOSTTask: ServerTask { }
public protocol ServerPATCHTask: ServerTask { }
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

public protocol ServerSentEventTargetTask: ServerTask {
	
}


// the protocols below all have associated types
public protocol PayloadDownloadingTask: ServerTask {
	associatedtype DownloadPayload: Decodable
	func postProcess(payload: DownloadPayload) async throws
}

public protocol PayloadUploadingTask: DataUploadingTask, JSONPayloadTask {
	associatedtype UploadPayload: Encodable
	var uploadPayload: UploadPayload? { get }
}

