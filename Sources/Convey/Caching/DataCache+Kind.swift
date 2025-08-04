//
//  SwiftUIView.swift
//  
//
//  Created by Ben Gottlieb on 7/2/23.
//

import Foundation

extension DataCache {	
	public enum Caching: Equatable, Sendable { case skipLocal, localFirst, localIfNewer(Date), localOnly, never }
	public enum CacheKind: Sendable { case `default`, keyed(String), fixed(URL), grouped(String, String?)
		var group: String? {
			switch self {
			case .grouped(let group, _): return group
			default: return nil
			}
		}
		
		func container(relativeTo parent: URL) -> URL? {
			switch self {
			case .grouped(let group, _):
				return parent.appendingPathComponent(group)
			default:
				return nil
			}
		}
	}
}

extension URL {
	var creationDate: Date? {
		// we're going to ignore any errors here. If we can't fetch the attributes, assume there are none
		guard
			isFileURL,
			let attributes = try? FileManager.default.attributesOfItem(atPath: path),
			let date = attributes[.creationDate] as? Date
		else { return nil }
		return date
	}
	
	var size: UInt64? {
		// we're going to ignore any errors here. If we can't fetch the attributes, assume there are none
		guard
			isFileURL,
			let attributes = try? FileManager.default.attributesOfItem(atPath: path),
			let size = attributes[.size] as? UInt64
		else { return nil }
		return size
	}
}

