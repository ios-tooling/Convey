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
}
