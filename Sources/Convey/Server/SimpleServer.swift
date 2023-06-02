//
//  SimpleServer.swift
//  
//
//  Created by Ben Gottlieb on 6/2/23.
//

import Foundation

public class SimpleServer: ConveyServer {
	public init(baseURL: URL) {
		super.init(asDefault: false)
		remote = .init(baseURL)
	}
}
