//
//  ConveyServer.Configuration.swift
//  Convey
//
//  Created by Ben Gottlieb on 10/3/24.
//

import Foundation

extension ConveyServer {
	public struct Configuration: Sendable {
		public var defaultEncoder = JSONEncoder()
		public var defaultDecoder = JSONDecoder()
		public var logDirectory: URL?
		public var reportBadHTTPStatusAsError = true
		public var urlSessionConfiguration = URLSessionConfiguration.default
		public var enableGZipDownloads = false
		public var archiveURL: URL?
		public var defaultTimeout = 30.0
		public var allowsExpensiveNetworkAccess = true
		public var allowsConstrainedNetworkAccess = true
		public var waitsForConnectivity = true
		public var maxLoggedDownloadSize = 1024 * 1024 * 10
		public var maxLoggedUploadSize = 1024 * 4
		public var defaultHeaders: [String: String] = [ ServerConstants.Headers.accept: "*/*" ]
		public var userAgent: String? = Self.defaultUserAgent
		
		
		public static let defaultUserAgent = "\(Bundle.main.name)/\(Bundle.main.version).\(Bundle.main.buildNumber)/\(Device.rawDeviceType)/CFNetwork/1325.0.1 Darwin/21.1.0"

	}
}
