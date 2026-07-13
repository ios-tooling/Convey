//
//  ServerConfiguration.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/19/25.
//

import Foundation

/// Constrains Convey requests to a specific network interface when the system's
/// normal route selection is not appropriate (for example, cellular cloud traffic
/// while Wi-Fi remains connected to a local instrument).
public enum ConveyNetworkInterface: String, Codable, CaseIterable, Sendable {
	case cellular
	case wifi
	case wiredEthernet
	case loopback
	case other
}

public struct ServerConfiguration: Sendable {
	public var defaultEncoder = JSONEncoder()
	public var defaultDecoder = JSONDecoder()
	public var urlSessionConfiguration = URLSessionConfiguration.default
	public var enableGZipDownloads = true
	public var enableGZipUploads = false
	public var logCancelledTasks = false
	public var defaultTimeout = 30.0
	public var allowsExpensiveNetworkAccess = true
	public var allowsConstrainedNetworkAccess = true
	public var waitsForConnectivity = true
	public var requiredNetworkInterface: ConveyNetworkInterface?
	public var maxLoggedDownloadSize = 1024 * 1024 * 10
	public var maxLoggedUploadSize = 1024 * 4
	public var defaultHeaders: Headers = [:]
	public var userAgent: String? = Self.defaultUserAgent
	public var pinExpiredToleranceInDays = 0.0
	public var enableTaskLoggingAtLaunch = false
	public var throwingStatusCategories = [400, 500]
	public var incompleteCategories = [500]					// if a connection returns an incomplete status, it will be saved and retried (if it's a StorableTask)
		
	public static let defaultUserAgent = "\(Bundle.main.name)/\(Bundle.main.version).\(Bundle.main.buildNumber)/\(Device.rawDeviceType)/CFNetwork/1325.0.1 Darwin/21.1.0"
	
	public static let `default` = ServerConfiguration()

	public init() { }
}
