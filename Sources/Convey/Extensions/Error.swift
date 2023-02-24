//
//  Error.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 5/16/22.
//

import Foundation

public extension Error {
	var isOffline: Bool {
		if let httpError = self as? HTTPError, httpError.isOffline { return true }
		return (self as NSError).code == -1009
	}
	
	var isTimeOut: Bool {
		if let urlError = self as? URLError, urlError.code == .timedOut { return true }
		return (self as NSError).domain == NSURLErrorDomain && (self as NSError).code == -1001
	}
}

public extension Array where Element == Error {
    var isOffline: Bool {
        !isEmpty && self.count == self.filter { $0.isOffline }.count
    }
}

