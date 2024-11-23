//
//  ServerTaskContainer.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 11/23/24.
//

import Foundation

public struct ServerTaskContainer<RootTask: ServerTask> {
	let root: RootTask
	
	init(root: RootTask) {
		self.root = root
	}
}
