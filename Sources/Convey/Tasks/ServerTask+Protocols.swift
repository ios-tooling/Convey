//
//  ServerTask+Protocols.swift
//
//
//  Created by Ben Gottlieb on 1/5/24.
//

import Foundation

// marker protocols
public protocol ServerCacheableTask { }
public protocol ServerUploadingTask: ServerTask { }
public protocol ServerGETTask: ServerTask { }
public protocol ServerPUTTask: ServerUploadingTask { }
public protocol ServerPOSTTask: ServerUploadingTask { }
public protocol ServerPATCHTask: ServerUploadingTask { }
public protocol ServerDELETETask: ServerTask { }

public protocol AllowedOnExpensiveNetworkTask: ServerTask { }
public protocol AllowedOnConstrainedNetworkTask: ServerTask { }
public protocol RefreshableCachedTask: ServerTask { }
public protocol ServerSentEventTargetTask: ServerTask { }
public protocol ETagCachedTask: ServerGETTask { }
public protocol JSONPayloadTask: ServerTask { }
public protocol GZipEncodedUploadingTask: DataUploadingTask { }
public protocol EchoingTask: ServerTask { }
public protocol DisabledShortEchoTask: ServerTask { }



@ConveyActor public protocol ParameterizedTask: ServerTask {
	var parameters: TaskURLParameters? { get }
}

@ConveyActor public protocol FileBackedTask: ServerTask {
	var fileURL: URL? { get }
}

@ConveyActor public protocol CustomURLTask: ServerTask {
	var customURL: URL? { get }
}

@ConveyActor public protocol TaggedTask: ServerTask {
	var requestTag: String { get }
}

@ConveyActor public protocol PayloadDownloadingTask<DownloadPayload>: ServerTask {
	associatedtype DownloadPayload: Decodable & Sendable
	func postProcess(payload: DownloadPayload) async throws
}

@ConveyActor public protocol DataUploadingTask: ServerUploadingTask {
	var dataToUpload: Data? { get }
	var contentType: String? { get }
}

@ConveyActor public protocol MIMEUploadingTask: DataUploadingTask {
	var mimeBoundary: String { get }
	var mimeFields: [MIMEMessageComponent]? { get }
	var base64EncodeBody: Bool { get }
}

@ConveyActor public protocol FormURLEncodedUploadingTask: DataUploadingTask {
	var formFields: [String: any Sendable] { get }
}

@ConveyActor public protocol JSONUploadingTask: DataUploadingTask, JSONPayloadTask {
	var jsonToUpload: [String: any Sendable]? { get }
}

@ConveyActor public protocol UnrecordedTask: ServerTask {
	var exposedComponents: [ServerTaskComponent] { get }
}

@ConveyActor public protocol CustomHTTPHeaders: ServerTask {
	var customHTTPHeaders: ConveyHeaders { get }
}

@ConveyActor public protocol ArchivingTask: ServerTask {
	var archiveURL: URL? { get }
}

@ConveyActor public protocol ThreadedServerTask: ServerTask {
	var threadName: String? { get }
}

@ConveyActor public protocol RetryableTask: ServerTask {
	func retryInterval(after error: Error, attemptNumber: Int) -> TimeInterval?
}

@ConveyActor public protocol PayloadUploadingTask: DataUploadingTask, JSONPayloadTask {
	associatedtype UploadPayload: Encodable
	var uploadPayload: UploadPayload? { get }
}

