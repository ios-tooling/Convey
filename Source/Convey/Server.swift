//
//  Server.swift
//  Server
//
//  Created by Ben Gottlieb on 9/11/21.
//

import Foundation
import Combine

open class Server: NSObject, ObservableObject {
	public static let instance = Server()
	
	
	@Published public var remote: Remote!
	
	public var baseURL: URL { remote.url }
	public var session: URLSession!
	public var isReady = CurrentValueSubject<Bool, Never>(false)
	public var recentServerError: Error? { didSet { self.objectWillChange.send() }}
	public var showCloudProblem = false
	public var defaultDecoder = JSONDecoder()
	
	override init() {
		super.init()
		let config = URLSessionConfiguration.default
		config.allowsCellularAccess = true
		config.allowsConstrainedNetworkAccess = true
		
		session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
	}

	open func url(forPath path: String) -> URL {
		baseURL.appendingPathComponent(path)
	}
}

extension Server: URLSessionDelegate {
	public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
		completionHandler(.useCredential, challenge.proposedCredential)
	}
}
