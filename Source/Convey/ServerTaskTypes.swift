//
//  ServerTask.swift
//  ServerTask
//
//  Created by Ben Gottlieb on 9/11/21.
//

import Suite

public protocol ServerTask {
	var path: String { get }
}

public protocol ParamaterizedTask: ServerTask {
	var parameters: [String: String]? { get }
}

public protocol PayloadReturningTask: ServerTask {
	associatedtype DownloadPayload: Decodable
}

public protocol CustomURLTask: ServerTask {
	var customURL: URL? { get }
}

public protocol CustomURLRequestTask: ServerTask {
	var customURLRequest: AnyPublisher<URLRequest?, Error> { get }
}

public protocol PayloadUploadingTask: ServerTask {
	associatedtype UploadPayload: Encodable
}

public protocol CustomHTTPMethodTask: ServerTask {
	var customHTTPMethod: String { get }
}

public protocol PreprocessingTask: ServerTask {
	func preprocess(data: Data, response: HTTPURLResponse) -> HTTPError?
}

public protocol ServerGETTask { }
public protocol ServerPUTTask { }
public protocol ServerPOSTTask { }
public protocol ServerPATCHTask{ }
public protocol ServerDELETETask { }


