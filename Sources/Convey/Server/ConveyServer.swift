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

extension CurrentValueSubject: @unchecked Sendable { }

open class ConveyServer: NSObject, ObservableObject, @unchecked Sendable {
	public static var serverInstance: ConveyServer! {
		get { _serverInstance.value }
		set { _serverInstance.value = newValue }
	}
	
	private static let _serverInstance: CurrentValueSubject<ConveyServer?, Never> = .init(nil)
	
	@Published open var remote: Remote = .empty
	
	open var baseURL: URL { remote.url }
	open var defaultEncoder = JSONEncoder()
	open var defaultDecoder = JSONDecoder()
	open var logDirectory: URL?
	open var reportBadHTTPStatusAsError = true
	open var configuration = URLSessionConfiguration.default
	open var enableGZipDownloads = false
	open var archiveURL: URL?
	open var defaultTimeout = 30.0
	open var allowsExpensiveNetworkAccess = true
	open var allowsConstrainedNetworkAccess = true
	open var waitsForConnectivity = true
	open var taskManager: ConveyTaskManager!
	public var logStyle: ConveyTaskManager.LogStyle?
	internal var effectiveLogStyle: ConveyTaskManager.LogStyle {
		get async { 
			if let logStyle { return logStyle }
			return await taskManager.logStyle
		}
	}

	public private(set) var taskPathURL: URL?
	
	var shouldRecordTaskPath: Bool { taskPathURL != nil }
	open var disabled = false { didSet {
		if disabled { print("#### \(String(describing: self)) DISABLED #### ")}
	}}
	public var userAgent: String? { didSet {
		updateUserAgentHeader()
		print("User agent set to: \(userAgent ?? "--")")
	}}
	open var maxLoggedDownloadSize = 1024 * 1024 * 10
	open var maxLoggedUploadSize = 1024 * 4
	open var launchedAt = Date()
	var activeSessions = ActiveSessions()
	public private(set) var pinnedServerKeys: [String: [String]] = [:]
	
	public func recordTaskPath(to url: URL? = nil) {
		pathCount = 0
		if let url {
			taskPathURL = url
			try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
			print("Recording tasks to \(url.path)")
		} else {
			if #available(iOS 16.0, macOS 13.0, *) {
				let name = Date.now.filename
				taskPathURL = URL.documentsDirectory.appendingPathComponent(name)
				try? FileManager.default.createDirectory(at: taskPathURL!, withIntermediateDirectories: true)
				print("Recording tasks to \(taskPathURL!.path)")
			} else {
				print("Please pass a valid URL to recordTaskPath(:)")
			}
		}
	}
	
	var pathCount = 0
	public func endTaskPathRecording() {
		self.taskPathURL = nil
	}
	
	public func register(publicKey: String, for server: String) {
		var keys = pinnedServerKeys[server, default: []]
		keys.append(publicKey)
		pinnedServerKeys[server] = keys
	}

	private var defaultHeaders: [String: String] = [
		ServerConstants.Headers.accept: "*/*"
	]
	let threadManager = ThreadManager()
	#if os(iOS)
		public var application: UIApplication?
	#endif
	
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
		if disabled { throw ConveyServerError.serverDisabled }
		if remote.isEmpty {
			if task.wrappedTask.url.host?.contains("about:") == false { return request }
			throw ConveyServerError.remoteNotSet
		}
		
		return request
	}
	
	open func postflight(_ task: ServerTask, result: ServerResponse) {
		
	}
	
	open func taskFailed(_ task: ServerTask, error: Error) {
		print("Error: \(error) from \(task)")
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
		taskManager = .init(for: self)
		if #available(iOS 16.0, macOS 13, *) {
			archiveURL = URL.libraryDirectory.appendingPathComponent("archived-downloads")
			try? FileManager.default.createDirectory(at: archiveURL!, withIntermediateDirectories: true)
		}
		if asDefault { Self.serverInstance = self }
	}
	
	open func standardHeaders(for task: ServerTask) async throws -> [String: String] {
		var headers = defaultHeaders
		if enableGZipDownloads {
			headers[ServerConstants.Headers.acceptEncoding] = "gzip, deflate"
		}
		return headers
	}
	
	open func url(forTask task: ServerTask) -> URL {
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
	var sessions: Set<ConveySession> = []
	
	var isEmpty: Bool { sessions.isEmpty }
	
	func insert(_ session: ConveySession) {
		sessions.insert(session)
	}
	
	func remove(_ session: ConveySession) {
		sessions.remove(session)
	}
}
