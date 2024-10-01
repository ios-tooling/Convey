//
//  ConveyServer+Accessors.swift
//  Personily
//
//  Created by Ben Gottlieb on 9/30/24.
//

import Foundation

public extension ConveyServer {
	nonisolated var remote: Remote {
		get { _remote.value }
		set {
			_remote.value = newValue
			objectWillChange.send()
		}
	}
	
	nonisolated var baseURL: URL { remote.url }
	nonisolated var defaultEncoder: JSONEncoder {
		get { _defaultEncoder.value }
		set { _defaultEncoder.value = newValue }
	}
	nonisolated var defaultDecoder: JSONDecoder {
		get { _defaultDecoder.value }
		set { _defaultDecoder.value = newValue }
	}
	nonisolated var logDirectory: URL? {
		get { _logDirectory.value }
		set { _logDirectory.value = newValue }
	}
	nonisolated var reportBadHTTPStatusAsError: Bool {
		get { _reportBadHTTPStatusAsError.value }
		set { _reportBadHTTPStatusAsError.value = newValue }
	}
	nonisolated var configuration: URLSessionConfiguration {
		get { _configuration.value }
		set { _configuration.value = newValue }
	}
	nonisolated var enableGZipDownloads: Bool {
		get { _enableGZipDownloads.value }
		set { _enableGZipDownloads.value = newValue }
	}
	nonisolated var archiveURL: URL? {
		get { _archiveURL.value }
		set { _archiveURL.value = newValue }
	}
	nonisolated var defaultTimeout: TimeInterval {
		get { _defaultTimeout.value }
		set { _defaultTimeout.value = newValue }
	}
	nonisolated var allowsExpensiveNetworkAccess: Bool {
		get { _allowsExpensiveNetworkAccess.value }
		set { _allowsExpensiveNetworkAccess.value = newValue }
	}
	nonisolated var allowsConstrainedNetworkAccess: Bool {
		get { _allowsConstrainedNetworkAccess.value }
		set { _allowsConstrainedNetworkAccess.value = newValue }
	}
	nonisolated var waitsForConnectivity: Bool {
		get { _waitsForConnectivity.value }
		set { _waitsForConnectivity.value = newValue }
	}
	nonisolated var taskManager: ConveyTaskManager!  {
		get { _taskManager.value }
		set { _taskManager.value = newValue }
	}
	nonisolated var logStyle: ConveyTaskManager.LogStyle? {
		get { _logStyle.value }
		set { _logStyle.value = newValue }
	}
	nonisolated var taskPath: TaskPath? {
		get { _taskPath.value }
	}
	nonisolated var maxLoggedDownloadSize: Int {
		get { _maxLoggedDownloadSize.value }
		set { _maxLoggedDownloadSize.value = newValue }
	}
	nonisolated var maxLoggedUploadSize: Int {
		get { _maxLoggedUploadSize.value }
		set { _maxLoggedUploadSize.value = newValue }
	}
	nonisolated var pinnedServerKeys: [String: [String]] {
		get { _pinnedServerKeys.value }
	}
}

extension ConveyServer {
	public var defaultUserAgent: String {
		"\(Bundle.main.name)/\(Bundle.main.version).\(Bundle.main.buildNumber)/\(Device.rawDeviceType)/CFNetwork/1325.0.1 Darwin/21.1.0"
	}
	
	internal var effectiveLogStyle: ConveyTaskManager.LogStyle {
		get async {
			if let logStyle { return logStyle }
			return await taskManager.logStyle
		}
	}
	
	nonisolated var shouldRecordTaskPath: Bool { taskPath != nil }

}
