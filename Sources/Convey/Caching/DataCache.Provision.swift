//
//  DataCache.Provision.swift
//  
//
//  Created by Ben Gottlieb on 7/3/23.
//

import Foundation

extension DataCache {
	nonisolated public func provision(url: URL, kind: CacheKind = .default, suffix: String? = nil, ext: String? = nil) -> Provision {
		Provision(url: url, kind: kind, suffix: suffix, ext: ext, root: cachesDirectory)
	}
	
	public struct Provision: Sendable {
		let url: URL
		var kind: CacheKind = .default
		var suffix: String?
		var ext: String?
		var root: URL
		
		var isLocal: Bool { url.isFileURL }
		var localURL: URL {
			if url.isFileURL { return url }

			let pathExtension = (ext ?? url.cachePathExtension ?? "dat" )
			var name = url.cacheKey
			if let suffix { name += suffix }
			name += "." + pathExtension
			
			switch kind {
			case .default:
				return root.appendingPathComponent(name)

			case .keyed(let key):
				return root.appendingPathComponent(key)
				
			case .fixed(let location):
				return location
				
			case .grouped(let group, let key):
				return root.appendingPathComponent(group).appendingPathComponent(key ?? name)
			}
		}
		
		func byAdding(suffix: String? = nil, extension ext: String?) -> Provision {
			var copy = self
			if let suffix { copy.suffix = suffix }
			if let ext { copy.ext = ext }
			return copy
		}
		
		func byRemovingSuffix() -> Provision {
			var copy = self
			copy.suffix = nil
			return copy
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
}
