//
//  FileManager.swift
//  
//
//  Created by Ben Gottlieb on 6/17/24.
//

import Foundation

extension FileManager {
	func removeItemIfExists(at url: URL) throws {
		guard fileExists(atPath: url.path) else { return }
		
		try removeItem(at: url)
	}
}
