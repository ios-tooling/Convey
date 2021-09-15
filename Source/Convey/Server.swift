//
//  Server.swift
//  Server
//
//  Created by Ben Gottlieb on 9/11/21.
//

import Suite

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
	open var maxLoggedDataSize = 1024 * 1024 * 10
	open var launchedAt = Date()
	open var defaultHeaders: [String: String] = [
		"Content-Type": "application/json",
		"Accept": "*"
	]
	
	public override init() {
		super.init()
		let config = URLSessionConfiguration.default
		config.allowsCellularAccess = true
		config.allowsConstrainedNetworkAccess = true
		
		session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
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
