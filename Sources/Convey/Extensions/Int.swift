//
//  Int.swift
//  Convey
//
//  Created by Ben Gottlieb on 10/4/24.
//

import Foundation

public extension Int {
	var isHTTPError: Bool {
		(self / 100) > 3
	}
	
	var isHTTPSuccess: Bool {
		(self / 100) == 2
	}
}
