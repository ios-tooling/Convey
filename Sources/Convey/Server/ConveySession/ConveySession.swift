//
//  ConveySession.swift
//
//
//  Created by Ben Gottlieb on 10/16/23.
//

import Foundation

class ConveySession: NSObject {
	var session: URLSession!
	let server: ConveyServer
	var queue: OperationQueue?
	
	var receivedData: Data?
	var streamContinuation: AsyncStream<ServerEvent>.Continuation?

	init(task: ServerTask) {
		server = task.server
		super.init()

		let config = task.server.configuration
		
		if task is AllowedOnExpensiveNetworkTask {
			config.allowsCellularAccess = true
			config.allowsExpensiveNetworkAccess = true
		} else {
			config.allowsCellularAccess = server.allowsExpensiveNetworkAccess
			config.allowsExpensiveNetworkAccess = server.allowsExpensiveNetworkAccess
		}
		
		if task is AllowedOnConstrainedNetworkTask {
			config.allowsConstrainedNetworkAccess = true
		} else {
			config.allowsConstrainedNetworkAccess = server.allowsConstrainedNetworkAccess
		}

		if task is ServerSentEventTargetTask {
			var additionalHeaders: [String: String] = [:]
			additionalHeaders["Accept"] = "text/event-stream"
			additionalHeaders["Cache-Control"] = "no-cache"

			config.timeoutIntervalForRequest = TimeInterval(INT_MAX)
			config.timeoutIntervalForResource = TimeInterval(INT_MAX)
			config.httpAdditionalHeaders = additionalHeaders
			
			queue = OperationQueue()
		}

		session = URLSession(configuration: config, delegate: self, delegateQueue: queue)
	}
	
	func data(for url: URL) async throws -> ServerReturned {
		try await data(for: URLRequest(url: url))
	}
	
	func data(for request: URLRequest) async throws -> ServerReturned {
		await server.register(session: self)
		let result = try await data(from: request)
		await server.unregister(session: self)
		return result
	}
}

extension ConveySession: URLSessionDelegate {
	public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
		
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


