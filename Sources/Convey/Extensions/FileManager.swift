//
//  FileManager.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/20/25.
//

import Foundation

extension FileManager {
	func removeItemIfExists(at url: URL) throws {
		guard fileExists(atPath: url.path) else { return }
		
		try removeItem(at: url)
	}
}
