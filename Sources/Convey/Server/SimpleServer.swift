//
//  SimpleServer.swift
//  
//
//  Created by Ben Gottlieb on 6/2/23.
//

import Foundation

@ConveyActor public class SimpleServer: ConveyServer, @unchecked Sendable {
	public init(baseURL: URL) {
		super.init(asDefault: false)
		remote = .init(baseURL)
	}
}
