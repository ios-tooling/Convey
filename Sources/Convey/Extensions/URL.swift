//
//  URL.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/20/25.
//

import Foundation

extension URL {
	var cachePathExtension: String? {
		let ext = pathExtension
		if !ext.isEmpty { return ext }
		return nil
	}
	
	static func systemDirectoryURL(which: FileManager.SearchPathDirectory) -> URL? {
		guard let path = NSSearchPathForDirectoriesInDomains(which, [.userDomainMask], true).first else { return nil }
		let url = URL(fileURLWithPath: path)
		  if !FileManager.default.fileExists(atPath: url.path) { try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil) }
		return url
	}
	
	var cacheKey: String {
		normalizedAbsoluteString.md5 ?? normalizedAbsoluteString
	}
	
	public var normalizedAbsoluteString: String {
		if isFileURL {
			let components = path.components(separatedBy: "/")
			if let index = components.firstIndex(of: "Application"), components.count > index + 2 {
				return components.dropFirst(index + 2).joined(separator: "/")
			}
			return path
		}
		guard let components = URLComponents(url: self, resolvingAgainstBaseURL: true) else { return absoluteString }
		
		var result = (components.scheme ?? "https") + "//"
		let creds = [components.user, components.password].compactMap { $0 }
		if !creds.isEmpty {
			result += creds.joined(separator: ":") + "@"
		}
		
		result += components.host ?? ""
		result += "/"
		result += components.path
		
		if let query = components.queryItems, !query.isEmpty {
			let sorted = query.sorted { $0.name < $1.name }
			result += "?"
			for item in sorted {
				result += item.name + "=" + (item.value ?? "") + "&"
			}
		}
		
		return result
	}
}
