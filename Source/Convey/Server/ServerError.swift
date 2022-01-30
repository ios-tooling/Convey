//
//  Server+Error.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 1/29/22.
//

import Foundation

enum ServerError: Error {
	case taskAlreadyStarted
	case unknownResponse(Data?, URLResponse?)
}
