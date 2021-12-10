//
//  Server.swift
//  Server
//
//  Created by Ben Gottlieb on 9/11/21.
//

import Suite
import Combine
import Foundation

open class Server: NSObject, ObservableObject {
	public static var serverInstance: Server!
	@Published public var remote: Remote!
	
	open var baseURL: URL { remote.url }
	open var session: URLSession!
	open var isReady = CurrentValueSubject<Bool, Never>(false)
	open var recentServerError: Error? { didSet { self.objectWillChange.sendOnMain() }}
	open var defaultEncoder = JSONEncoder()
	open var defaultDecoder = JSONDecoder()
	open var logDirectory: URL?
	open var configuration = URLSessionConfiguration.default
	public var userAgent: String? { didSet { updateUserAgentHeader() }}
	open var maxLoggedDataSize = 1024 * 1024 * 10
	open var launchedAt = Date()
	private var defaultHeaders: [String: String] = [
		"Content-Type": "application/json",
		"Accept": "*"
	]
	
	public var defaultUserAgent: String {
		"\(Bundle.main.name)/\(Bundle.main.version).\(Bundle.main.buildNumber)/\(Gestalt.rawDeviceType)/CFNetwork/1325.0.1 Darwin/21.1.0"
	}
	public func clearLogs() {
		if let dir = logDirectory { try? FileManager.default.removeItem(at: dir) }
	}

	public func setStandardHeaders(_ headers: [String: String]) {
		self.defaultHeaders = headers
		updateUserAgentHeader()
	}
	
	open func preflight(_ task: ServerTask, request: URLRequest) -> AnyPublisher<URLRequest, Error> {
		Just(request).setFailureType(to: Error.self).eraseToAnyPublisher()
	}
	
	@available(macOS 12.1, iOS 15.0, watchOS 8.0, *)
	open func preflight(_ task: ServerTask, request: URLRequest) async throws -> URLRequest {
		request
	}

	public static func setupDefault() {
		_ = Server()
	}

	func updateUserAgentHeader() {
		if let agent = userAgent {
			defaultHeaders["User-Agent"] = agent
		} else {
			defaultHeaders.removeValue(forKey: "User-Agent")
		}
	}
	
	public override init() {
		super.init()
		configuration.allowsCellularAccess = true
		configuration.allowsConstrainedNetworkAccess = true
		
		session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
		Self.serverInstance = self
	}

	open func standardHeaders() -> [String: String] {
		defaultHeaders
	}

	open func url(forPath path: String) -> URL {
		baseURL.appendingPathComponent(path)
	}

	open func handle(error: Error, from task: ServerTask) {
		print("Error: \(error) from \(task)")
	}
}

extension Server: URLSessionDelegate {
	public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
		completionHandler(.useCredential, challenge.proposedCredential)
	}
}