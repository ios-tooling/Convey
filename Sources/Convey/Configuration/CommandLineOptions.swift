//
//  CommandLineOptions.swift
//  Convey
//
//  Created by Ben Gottlieb on 12/8/25.
//

import Foundation

extension CommandLine {
	@inline(__always) static var failAllRequests: Bool {
		#if DEBUG
			CommandLine.bool(for: "fail-all-requests")
		#else
			false
		#endif
	}
}
