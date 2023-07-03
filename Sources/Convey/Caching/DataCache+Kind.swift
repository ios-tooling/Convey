//
//  SwiftUIView.swift
//  
//
//  Created by Ben Gottlieb on 7/2/23.
//

import Foundation

extension DataCache {
	public struct Provision {
		let url: URL
		var kind: CacheKind = .default
		var suffix: String?
		var ext: String?
		var root: URL
		
		var isLocal: Bool { url.isFileURL }
		var location: URL {
			if url.isFileURL { return url }
			return kind.location(of: url, relativeTo: root)
		}
		
		var key: String {
			switch kind {
			case .default:
				return url.cacheKey + (suffix ?? "") + "." + (ext ?? "")

			case .keyed(let key):
				return key
				
			case .fixed:
				return url.cacheKey
				
			case .grouped(let group, let key):
				return group + "/" + (key ?? (url.cacheKey + "." + (ext ?? "")))

			}
		}
		
		var group: String? { kind.group }
	}
	
	public func provision(url: URL, kind: CacheKind = .default, suffix: String? = nil, ext: String? = nil) -> Provision {
		Provision(url: url, kind: kind, suffix: suffix, ext: ext, root: cachesDirectory)
	}
	
	public enum Caching: Equatable { case skipLocal, localFirst, localIfNewer(Date), localOnly, never }
	public enum CacheKind { case `default`, keyed(String), fixed(URL), grouped(String, String?)
		func location(of url: URL, relativeTo parent: URL, extension ext: String? = nil) -> URL {
			let pathExtension = (ext ?? url.cachePathExtension ?? "dat" )
			switch self {
			case .default:
				return parent.appendingPathComponent(url.cacheKey + "." + pathExtension)

			case .keyed(let key):
				return parent.appendingPathComponent(key)
				
			case .fixed(let location):
				return location
				
			case .grouped(let group, let key):
				return parent.appendingPathComponent(group).appendingPathComponent(key ?? (url.cacheKey + "." + pathExtension))

			}
		}
		
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

		func localURL(for remote: URL, key: String?, group: String?, parent: URL, preferred: URL?) -> URL {
			if let location = preferred { return location }
			
			let actualKey = key ?? (remote.cacheKey + ".dat")
			
			if let group = group {
				return parent.appendingPathComponent(group).appendingPathComponent(actualKey)
			}
			
			return parent.appendingPathComponent(actualKey)
		}
	}
}

extension URL {
	var creationDate: Date? {
		guard
			isFileURL,
			let attributes = try? FileManager.default.attributesOfItem(atPath: path),
			let date = attributes[.creationDate] as? Date
		else { return nil }
		return date
	}
	
	var size: UInt64? {
		guard
			isFileURL,
			let attributes = try? FileManager.default.attributesOfItem(atPath: path),
			let size = attributes[.size] as? UInt64
		else { return nil }
		return size
	}
}

