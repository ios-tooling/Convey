//
//  ConveyServer.swift
//  ConveyServer
//
//  Created by Ben Gottlieb on 9/11/21.
//

import Combine
import Foundation

#if os(iOS)
import UIKit
#endif

@globalActor public actor ConveyActor: GlobalActor {
	public static let shared = ConveyActor()
}

extension CurrentValueSubject: @retroactive @unchecked Sendable { }

@ConveyActor public class SharedServer {
	public static nonisolated var instance: ConveyServer! {
		get { SharedServer._serverInstance.value }
		set { SharedServer._serverInstance.value = newValue }
	}
	
	nonisolated static let _serverInstance: CurrentValueSubject<ConveyServer?, Never> = .init(nil)
}

@ConveyActor open class ConveyServer: ObservableObject {
	// public vars
	open nonisolated var remote: Remote {
		get { _remote.value }
		set { _remote.value = newValue }
	}
	nonisolated private let _remote: CurrentValueSubject<Remote, Never> = .init(.empty)
	
	public var disabled = false { didSet { if disabled { print("#### \(String(describing: self)) DISABLED #### ")} }}

	public let launchedAt = Date()
	public var baseURL: URL { remote.url }
	public internal(set) var taskPath: TaskPath?

	// internal vars
	var shouldRecordTaskPath: Bool { taskPath != nil }
	var activeSessions = ActiveSessions()
	let threadManager = ThreadManager()

	nonisolated let configurationSubject = CurrentValueSubject<Configuration, Never>(.init())
	nonisolated let pinnedServerKeysSubject = CurrentValueSubject<[String: [String]], Never>(.init())
	#if os(iOS)
		nonisolated let applicationSubject = CurrentValueSubject<UIApplication?, Never>(nil)
	#endif
	

	
	public init(asDefault: Bool = true) {
		if #available(iOS 16.0, macOS 13, watchOS 9, *) {
			configuration.archiveURL = URL.libraryDirectory.appendingPathComponent("archived-downloads")
			try? FileManager.default.createDirectory(at: configuration.archiveURL!, withIntermediateDirectories: true)
		}
		if asDefault { SharedServer.instance = self }
	}
	
	open func preflight(_ task: any ServerConveyable, request: URLRequest) async throws -> URLRequest {
		if disabled { throw ConveyServerError.serverDisabled }
		if remote.isEmpty {
			if task.wrappedTask.url.host?.contains("about:") == false { return request }
			throw ConveyServerError.remoteNotSet
		}
		
		return request
	}
	
	open func postflight(_ task: any ServerConveyable, result: ServerResponse) { }
	
	open func taskFailed(_ task: any ServerConveyable, error: Error) async { print("Error: \(error) from \(task)") }
	
	open func standardHeaders(for task: any ServerConveyable) async throws -> [String: String] {
		var headers = configuration.defaultHeaders
		if let agent = configuration.userAgent { headers[ServerConstants.Headers.userAgent] = agent }
		if configuration.enableGZipDownloads {
			headers[ServerConstants.Headers.acceptEncoding] = "gzip, deflate"
		}
		return headers
	}
	
	open func url(forTask task: any ServerConveyable) -> URL {
		var path = task.path
		if path.hasPrefix("/") { path.removeFirst() }
		return baseURL.appendingPathComponent(path)
	}
	
	open var reportConnectionError: (any ServerConveyable, Int, String?) -> Void = { task, code, description in
		print("\(type(of: task)), \(task.url) Connection error: \(code): \(description ?? "Unparseable error")")
	}
	
	public func setRemote(_ remote: Remote) {
		self.remote = remote
	}
}
