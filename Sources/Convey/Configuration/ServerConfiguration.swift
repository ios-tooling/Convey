//
//  ServerConfiguration.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/19/25.
//

import Foundation

public struct ServerConfiguration: Sendable {
	public var defaultEncoder = JSONEncoder()
	public var defaultDecoder = JSONDecoder()
	public var urlSessionConfiguration = URLSessionConfiguration.default
	public var enableGZipDownloads = true
	public var enableGZipUploads = false
	public var defaultTimeout = 30.0
	public var allowsExpensiveNetworkAccess = true
	public var allowsConstrainedNetworkAccess = true
	public var waitsForConnectivity = true
	public var maxLoggedDownloadSize = 1024 * 1024 * 10
	public var maxLoggedUploadSize = 1024 * 4
	public var defaultHeaders: Headers = [:]
	public var userAgent: String? = Self.defaultUserAgent
	public var pinExpiredToleranceInDays = 0.0
	public var enableTaskLoggingAtLaunch = false
	public var throwingStatusCategories = [400, 500]
		
	public static let defaultUserAgent = "\(Bundle.main.name)/\(Bundle.main.version).\(Bundle.main.buildNumber)/\(Device.rawDeviceType)/CFNetwork/1325.0.1 Darwin/21.1.0"
	
	public static let `default` = ServerConfiguration()

	public init() { }
}
