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

public struct DefaultServer {
	static nonisolated let _server: CurrentValueSubject<ConveyServer?, Never> = .init(nil)
	public static var server: ConveyServer {
		get { _server.value! }
		set { _server.value = newValue }
	}
}

extension CurrentValueSubject: @retroactive @unchecked Sendable { }

@MainActor open class ConveyServer: NSObject, ObservableObject {
	nonisolated let _remote: CurrentValueSubject<Remote, Never> = .init(.empty)
	
	nonisolated let _defaultEncoder: CurrentValueSubject<JSONEncoder, Never> = .init(JSONEncoder())
	nonisolated let _defaultDecoder: CurrentValueSubject<JSONDecoder, Never> = .init(JSONDecoder())
	nonisolated let _logDirectory: CurrentValueSubject<URL?, Never> = .init(nil)
	nonisolated let _reportBadHTTPStatusAsError: CurrentValueSubject<Bool, Never> = .init(true)
	nonisolated let _configuration: CurrentValueSubject<URLSessionConfiguration, Never> = .init(.default)
	nonisolated let _enableGZipDownloads: CurrentValueSubject<Bool, Never> = .init(false)
	nonisolated let _archiveURL: CurrentValueSubject<URL?, Never> = .init(nil)
	nonisolated let _defaultTimeout: CurrentValueSubject<TimeInterval, Never> = .init(30.0)
	nonisolated let _allowsExpensiveNetworkAccess: CurrentValueSubject<Bool, Never> = .init(true)
	nonisolated let _allowsConstrainedNetworkAccess: CurrentValueSubject<Bool, Never> = .init(true)
	nonisolated let _waitsForConnectivity: CurrentValueSubject<Bool, Never> = .init(true)
	nonisolated let _taskManager: CurrentValueSubject<ConveyTaskManager?, Never> = .init(nil)
	nonisolated let _logStyle: CurrentValueSubject<ConveyTaskManager.LogStyle?, Never> = .init(nil)
	nonisolated let _taskPath: CurrentValueSubject<TaskPath?, Never> = .init(nil)
	nonisolated let _maxLoggedDownloadSize: CurrentValueSubject<Int, Never> = .init(1024 * 1024 * 10)
	nonisolated let _maxLoggedUploadSize: CurrentValueSubject<Int, Never> = .init(1024 * 4)
	nonisolated let _pinnedServerKeys: CurrentValueSubject<[String: [String]], Never> = .init([:])

	#if os(iOS)
		public var application: UIApplication?
	#endif

	public var disabled = false { didSet {
		if disabled { print("#### \(String(describing: self)) DISABLED #### ")}
	}}
	public var userAgent: String? { didSet {
		updateUserAgentHeader()
		print("User agent set to: \(userAgent ?? "--")")
	}}
	public let launchedAt = Date()
	var activeSessions = ActiveSessions()
	
	nonisolated public func recordTaskPath(to url: URL? = nil) {
		if let url {
			_taskPath.value = .init(url: url)
		} else {
			if #available(iOS 16.0, macOS 13, *) {
				_taskPath.value = .init()
			}
		}
		objectWillChange.send()
	}
	
	nonisolated public func endTaskPathRecording() {
		self.taskPath?.stop()
		_taskPath.value = nil
		objectWillChange.send()
	}
	
	public func register(publicKey: String, for server: String) {
		var keys = pinnedServerKeys[server, default: []]
		keys.append(publicKey)
		_pinnedServerKeys.value[server] = keys
	}

	private var defaultHeaders: [String: String] = [
		ServerConstants.Headers.accept: "*/*"
	]
	let threadManager = ThreadManager()
	
	public func clearLogs() {
		if let dir = logDirectory { try? FileManager.default.removeItem(at: dir) }
	}
	
	public func setStandardHeaders(_ headers: [String: String]) {
		self.defaultHeaders = headers
		updateUserAgentHeader()
	}

	open func preflight(_ task: ServerTask, request: URLRequest) async throws -> URLRequest {
		if disabled { throw ConveyServerError.serverDisabled }
		if remote.isEmpty {
			if task.wrappedTask.url.host?.contains("about:") == false { return request }
			throw ConveyServerError.remoteNotSet
		}
		
		return request
	}
	
	open func postflight(_ task: ServerTask, result: ServerResponse) {
		
	}
	
	nonisolated open func taskFailed(_ task: ServerTask, error: Error) {
		print("Error: \(error) from \(task)")
	}
	
	public static func setupDefault(server: ConveyServer? = nil) -> ConveyServer {
		DefaultServer.server = server ?? ConveyServer()
		return DefaultServer.server
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
		if asDefault { DefaultServer.server = self }
		taskManager = .init(for: self)
		if #available(iOS 16.0, macOS 13, watchOS 9, *) {
			archiveURL = URL.libraryDirectory.appendingPathComponent("archived-downloads")
			try? FileManager.default.createDirectory(at: archiveURL!, withIntermediateDirectories: true)
		}
		if asDefault { DefaultServer.server = self }
	}
	
	open func standardHeaders(for task: ServerTask) async throws -> [String: String] {
		var headers = defaultHeaders
		if enableGZipDownloads {
			headers[ServerConstants.Headers.acceptEncoding] = "gzip, deflate"
		}
		return headers
	}
	
	nonisolated open func url(forTask task: ServerTask) -> URL {
		var path = task.path
		if path.hasPrefix("/") { path.removeFirst() }
		return baseURL.appendingPathComponent(path)
	}
	
	open var reportConnectionError: (ServerTask, Int, String?) -> Void = { task, code, description in
		  print("\(type(of: task)), \(task.url) Connection error: \(code): \(description ?? "Unparseable error")")
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

actor ActiveSessions {
	let sessions: CurrentValueSubject<Set<ConveySession>, Never> = .init([])
	
	nonisolated var isEmpty: Bool { sessions.value.isEmpty }
	
	func insert(_ session: ConveySession) {
		var value = sessions.value
		value.insert(session)
		sessions.send(value)
	}
	
	func remove(_ session: ConveySession) {
		var value = sessions.value
		value.remove(session)
		sessions.send(value)
	}
}
