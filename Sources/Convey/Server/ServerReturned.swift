//
//  ServerReturned.swift
//  
//
//  Created by Ben Gottlieb on 12/19/22.
//

import Foundation

public struct ServerReturned: Sendable {
	public var response: HTTPURLResponse
	public var data: Data
	public var fromCache: Bool
	public var duration: TimeInterval?
	
	public var statusCode: Int { response.statusCode }
}
