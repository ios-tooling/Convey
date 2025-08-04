//
//  ETagStore.swift
//  
//
//  Created by Ben Gottlieb on 9/10/22.
//

import Foundation

@ConveyActor class ETagStore {
	static let instance = ETagStore()
	
	var etags: [URL: String] = [:]
	let filename = "etags.txt"
	public var directory = URL.systemDirectoryURL(which: .cachesDirectory)!
	var url: URL { directory.appendingPathComponent(filename) }
	func validateDirectories() {
		// we're going to ignore any errors here. If we can't fetch the create the directory, we won't be able to cache stuff
		try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true) }

	init() {
		Task { load() }
	}
	
	func store(etag: String, for url: URL) {
		etags[url] = etag
		save()
	}
	
	func eTag(for url: URL) -> String? {
		etags[url]
	}
	
	func save() {
		// we're going to ignore any errors here. If we can't save the data, oh well
		if let data = try? JSONEncoder().encode(etags) {
			try? data.write(to: url)
		}
	}
	
	func load() {
		// we're going to ignore any errors here. If we can't fetch the data, we can't restore a cache
		guard let data = try? Data(contentsOf: url) else { return }
		
		let tags = (try? JSONDecoder().decode([URL: String].self, from: data)) ?? [:]
		etags = tags
	}
}

