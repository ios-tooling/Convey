//
//  Server.Remote.swift
//  Server.Remote
//
//  Created by Ben Gottlieb on 9/11/21.
//

import Foundation

public extension Server {
	struct Remote {
		let name: String?
		let url: URL
		
		init(name: String? = nil, url: URL) {
			self.name = name
			self.url = url
		}
	}
}
