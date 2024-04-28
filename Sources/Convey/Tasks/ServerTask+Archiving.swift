//
//  ServerTask+Archiving.swift
//  
//
//  Created by Ben Gottlieb on 12/1/23.
//

import Foundation

public extension ArchivingTask {
	var archiveURL: URL? {
		server.archiveURL?.appendingPathComponent(String(cString: (String(describing: self) as NSString).fileSystemRepresentation) + ".json")
	}
	
	func archive(_ result: ServerResponse) {
		guard let url = archiveURL else {
			print("Tried to archive \(self), no URL specified")
			return
		}
		
		print("Archiving \(String(describing: Self.self)) to \(url.path)")
		try? result.data.write(to: url)
	}
}
