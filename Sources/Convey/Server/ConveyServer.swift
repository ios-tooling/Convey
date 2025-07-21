//
//  ConveyServer.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/19/25.
//

import Foundation

public class ConveyServer: ConveyServerable {
	public static var `default`: ConveyServerable = ConveyServer()
	
	public var remote = Remote.empty
	public var configuration = ServerConfiguration()
	public var downloadQueue: OperationQueue? = .init()
}
