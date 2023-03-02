//
//  ConveyServer.swift
//  ConveyServer
//
//  Created by Ben Gottlieb on 9/11/21.
//

import Combine
import Foundation

open class ConveyServer: NSObject, ObservableObject {
	public static var serverInstance: ConveyServer!
	@Published public var remote: Remote = Remote(URL(string: "about://")!)
	
	open var baseURL: URL { remote.url }
	open var session: URLSession!
	open var isReady = CurrentValueSubject<Bool, Never>(false)
	open var recentServerError: Error? { didSet { Task { await MainActor.run { self.objectWillChange.send() }} }}
	open var defaultEncoder = JSONEncoder()
	open var defaultDecoder = JSONDecoder()
	open var logDirectory: URL?
	open var reportBadHTTPStatusAsError = true
	open var configuration = URLSessionConfiguration.default
	open var enableGZip = false
	public var userAgent: String? { didSet {
		updateUserAgentHeader()
		print("User agent set to: \(userAgent ?? "--")")
	}}
	open var maxLoggedDataSize = 1024 * 1024 * 10
	open var maxLoggedUploadSize = 1024 * 4
	open var launchedAt = Date()
	open var echoAll = false
	private var defaultHeaders: [String: String] = [
		ServerConstants.Headers.accept: "*/*"
	]
	let threadManager = ThreadManager()
	
	public var defaultUserAgent: String {
		"\(Bundle.main.name)/\(Bundle.main.version).\(Bundle.main.buildNumber)/\(Device.rawDeviceType)/CFNetwork/1325.0.1 Darwin/21.1.0"
	}
	public func clearLogs() {
		if let dir = logDirectory { try? FileManager.default.removeItem(at: dir) }
	}
	
	public func setStandardHeaders(_ headers: [String: String]) {
		self.defaultHeaders = headers
		updateUserAgentHeader()
	}

	open func preflight(_ task: ServerTask, request: URLRequest) async throws -> URLRequest {
		request
	}
	
	public static func setupDefault() -> ConveyServer {
		_ = ConveyServer()
		return serverInstance
	}
	
	func updateUserAgentHeader() {
		if let agent = userAgent {
			defaultHeaders[ServerConstants.Headers.userAgent] = agent
		} else {
			defaultHeaders.removeValue(forKey: ServerConstants.Headers.userAgent)
		}
	}

	public convenience override init() { self.init(asDefault: true) }

	public init(asDefault: Bool = true) {
		super.init()
		configuration.allowsCellularAccess = true
		configuration.allowsConstrainedNetworkAccess = true
		
		session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
		if asDefault { Self.serverInstance = self }
	}
	
	open func standardHeaders(for task: ServerTask) async throws -> [String: String] {
		var headers = defaultHeaders
		if enableGZip {
			headers[ServerConstants.Headers.acceptEncoding] = "gzip, deflate"
		}
		return headers
	}
	
	open func url(forTask task: ServerTask) -> URL {
		baseURL.appendingPathComponent(task.path)
	}
	
	open func handle(error: Error, from task: ServerTask) {
		print("Error: \(error) from \(task)")
	}
	
	open var reportConnectionError: (ServerTask, Int, String?) -> Void = { task, code, description in
        print("\(type(of: task)), \(task.url) Connection error: \(code): \(description ?? "Unparseable error")")
	}
}

extension ConveyServer: URLSessionDelegate {
	public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
		if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
			if let serverTrust = challenge.protectionSpace.serverTrust {
				let credential = URLCredential(trust: serverTrust)
				completionHandler(URLSession.AuthChallengeDisposition.useCredential, credential)
				return
			}
		}
		completionHandler(.useCredential, challenge.proposedCredential)
	}
}

public extension Int {
	var isHTTPError: Bool {
		(self / 100) > 3
	}
	
	var isHTTPSuccess: Bool {
		(self / 100) == 2
	}
}
