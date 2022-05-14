//
//  Server+Error.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 1/29/22.
//

import Foundation

public enum ServerError: LocalizedError {
	case taskAlreadyStarted
	case unknownResponse(Data?, URLResponse?)
    
    public var errorDescription: String? {
        switch self {
        case .taskAlreadyStarted: return "Task already started"
        case .unknownResponse(let data, let response):
            let code = (response as? HTTPURLResponse)?.statusCode ?? 600
            let message = String(data: data ?? Data(), encoding: .utf8) ?? "Unparseable Response"
            
            return "\(code): \(message)"
        }
    }
}
