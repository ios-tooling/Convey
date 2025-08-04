//
//  URLSession.swift
//  Convey
//
//  Created by Ben Gottlieb on 8/3/25.
//

import Foundation

extension URLSession {
	var configurationFingerprint: String { configuration.fingerprint }
	
	func hasSameConfiguration(as other: URLSession) -> Bool {
		self.configurationFingerprint == other.configurationFingerprint
	}
	
	func hasSameConfiguration(as other: URLSessionConfiguration) -> Bool {
		self.configurationFingerprint == other.fingerprint
	}
}

extension URLSessionConfiguration {
	fileprivate var fingerprint: String {
		return [
			String(self.allowsExpensiveNetworkAccess),
			String(self.allowsConstrainedNetworkAccess),
			String(self.timeoutIntervalForRequest),
			String(self.timeoutIntervalForResource),
			String(self.httpShouldSetCookies),
			String(self.httpShouldUsePipelining),
			String(self.httpMaximumConnectionsPerHost),
			self.httpAdditionalHeaders?.description ?? "nil"
		].joined(separator: "_")
	}
	

}
