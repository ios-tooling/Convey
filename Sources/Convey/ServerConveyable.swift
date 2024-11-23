//
//  ServerConveyable.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 11/23/24.
//

import Foundation

public protocol ServerConveyable {
	
}

public protocol ServerDownloadConveyable: ServerConveyable {
	associatedtype DownloadPayload: Decodable & Sendable
}

public protocol ServerUploadConveyable: ServerConveyable {
	associatedtype UploadPayload: Decodable & Sendable
}
