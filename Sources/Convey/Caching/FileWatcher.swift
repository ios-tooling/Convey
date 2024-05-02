//
//  FileWatcher.swift
//
//
//  Created by Ben Gottlieb on 5/2/24.
//

import Foundation

struct FileWatcher {
	var source: (any DispatchSourceFileSystemObject)!
	
	func finish() {
		source?.cancel()
	}
	
	init(url: URL, queue: DispatchQueue = .main, changed: @escaping @Sendable (URL) -> Void) throws {
		let fileHandle = try FileHandle(forReadingFrom: url)
		
		source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileHandle.fileDescriptor, eventMask: .all, queue: queue)
		
		source.setEventHandler {
			changed(url)
		}
		
		source.setCancelHandler {
			try? fileHandle.close()
		}
	}
}
