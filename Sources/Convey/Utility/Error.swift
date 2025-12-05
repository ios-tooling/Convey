//
//  Error.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/20/25.
//

import Foundation

public extension Error {
	var httpStatusCode: Int? {
		guard let urlError = self as? URLError else { return nil }
		
		return urlError.errorCode
	}
	
	var prettyDescription: String {
		if isTimeOut { return "timed out" }
		if isOffline { return "offline" }
		
		return localizedDescription
	}
}

extension Error {
	var isOffline: Bool {
		return (self as NSError).code == -1009
	}
	
	var isTimeOut: Bool {
		if let urlError = self as? URLError, urlError.code == .timedOut { return true }
		return (self as NSError).domain == NSURLErrorDomain && (self as NSError).code == -1001
	}
	
	var isCancellation: Bool {
		if self is CancellationError { return true }
		  
		let error = self as NSError
		
		return abs(error.code) == 999
	}
}
