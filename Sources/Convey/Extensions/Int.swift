//
//  File.swift
//  Convey
//
//  Created by Ben Gottlieb on 8/7/25.
//

import Foundation

public extension Int {
	@MainActor static let byteFormatter = ByteCountFormatter()
	
	@MainActor var bytesString: String {
		Self.byteFormatter.string(fromByteCount: Int64(self))
	}
}


