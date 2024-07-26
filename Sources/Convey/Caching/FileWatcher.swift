//
//  FileWatcher.swift
//
//
//  Created by Ben Gottlieb on 5/2/24.
//

import Foundation

public struct FileWatcher {
	var source: (any DispatchSourceFileSystemObject)!
	
	func finish() {
		source?.cancel()
	}
	
	init?(url: URL, queue: DispatchQueue = .main, changed: @escaping @Sendable (URL) -> Void) throws {
		guard FileManager.default.fileExists(atPath: url.path) else { return nil }
		let fileHandle = try FileHandle(forReadingFrom: url)
		
		source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileHandle.fileDescriptor, eventMask: .extend, queue: queue)
		
		source.setEventHandler {
			changed(url)
		}
		
		source.setCancelHandler {
			try? fileHandle.close()
		}
		
		source.resume()
	}
}
