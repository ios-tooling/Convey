//
//  File.swift
//  Convey
//
//  Created by Ben Gottlieb on 10/3/24.
//

import Foundation

extension ConveyServer {
	public struct Configuration {
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
	}
}
