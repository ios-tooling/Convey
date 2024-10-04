//
//  ConveySession.swift
//
//
//  Created by Ben Gottlieb on 10/16/23.
//

import Foundation
import Combine

actor ConveySession: NSObject {
	var session: URLSession!
	let server: ConveyServer
	var queue: OperationQueue?
	
	nonisolated let receivedData: CurrentValueSubject<Data?, Never> = .init(nil)
	nonisolated let streamContinuation: CurrentValueSubject<AsyncStream<ServerEvent>.Continuation?, Never> = .init(nil)
	
	override init() {
		server = ConveyServer.serverInstance
		super.init()
		session = URLSession(configuration: .default, delegate: self, delegateQueue: queue)
	}
	
	init(task: ServerTask) {
		server = task.server
		super.init()

		let config = task.server.configuration.urlSessionConfiguration.copy() as! URLSessionConfiguration
		
		if task.wrappedTask is AllowedOnExpensiveNetworkTask {
			config.allowsCellularAccess = true
			config.allowsExpensiveNetworkAccess = true
		} else {
			config.allowsCellularAccess = server.configuration.allowsExpensiveNetworkAccess
			config.allowsExpensiveNetworkAccess = server.configuration.allowsExpensiveNetworkAccess
		}
		
		if task.wrappedTask is AllowedOnConstrainedNetworkTask {
			config.allowsConstrainedNetworkAccess = true
		} else {
			config.allowsConstrainedNetworkAccess = server.configuration.allowsConstrainedNetworkAccess
		}

		if task.wrappedTask is ServerSentEventTargetTask {
			var additionalHeaders: [String: String] = [:]
			additionalHeaders["Accept"] = "text/event-stream"
			additionalHeaders["Cache-Control"] = "no-cache"

			config.timeoutIntervalForRequest = TimeInterval(INT_MAX)
			config.timeoutIntervalForResource = TimeInterval(INT_MAX)
			config.httpAdditionalHeaders = additionalHeaders
			
			queue = OperationQueue()
		}
		
		let timeout = task.timeout
		
		config.timeoutIntervalForRequest = timeout
		config.timeoutIntervalForResource = timeout

		config.waitsForConnectivity = server.configuration.waitsForConnectivity
		session = URLSession(configuration: config, delegate: self, delegateQueue: queue)
	}
	
	func data(for url: URL) async throws -> ServerResponse {
		try await data(for: URLRequest(url: url))
	}
	
	func data(for request: URLRequest) async throws -> ServerResponse {
		await server.register(session: self)
		let result = try await data(from: request)
		await server.unregister(session: self)
		session.finishTasksAndInvalidate()
		session = nil
		return result
	}
}

extension ConveySession: URLSessionDelegate {
	public nonisolated func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
		
		if let keys = server.pinnedServerKeys[challenge.host] {
			guard let key = challenge.publicKey, keys.contains(key) else {
				print("Failed to verify public key for \(challenge.host)")
				completionHandler(.cancelAuthenticationChallenge, nil)
				return
			}
		}
		
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


