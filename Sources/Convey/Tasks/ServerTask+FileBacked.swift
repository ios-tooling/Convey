//
//  ServerTask+FileBased.swift
//  
//
//  Created by Ben Gottlieb on 11/30/21.
//

import Foundation
import Combine

public extension ServerTask where Self: FileBackedTask & PayloadDownloadingTask {
	func fileCachedDownload(using decoder: JSONDecoder? = nil) throws -> DownloadPayload? {
		guard let data = fileCachedData else { return nil }
		do {
			return try decode(data: data, decoder: decoder)
		} catch {
			print("Error when decoding \(DownloadPayload.self) in \(self): \(error)")
			throw error
		}
	}
}

public extension ServerConveyable {
	var fileCachedData: Data? {
		get {
			guard let fileProvider = self.wrappedTask as? FileBackedTask else { return nil }
			guard let file = fileProvider.fileURL else { return nil }
			
			return try? Data(contentsOf: file)
		}
		
		nonmutating set {
			guard let fileProvider = self.wrappedTask as? FileBackedTask else { return }
			guard let file = fileProvider.fileURL else { return }
			
			if let data = newValue {
				do {
					try data.write(to: file)
				} catch {
					print("Failed to store backing file for \(self), \(error)")
				}
			} else {
				try? FileManager.default.removeItem(at: file)
			}
		}
	}
}
