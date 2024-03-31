//
//  ConveyServerError.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 1/29/22.
//

import Foundation

public enum ConveyServerError: LocalizedError, Sendable {
	case remoteNotSet
	case serverDisabled
	case taskAlreadyStarted
	case unknownResponse(Data?, URLResponse?)
	case endOfRepetition
    
    public var errorDescription: String? {
        switch self {
		  case .remoteNotSet: return "You've not yet set a remote for this server"
		  case .serverDisabled: return "Server DISABLED"
        case .taskAlreadyStarted: return "Task already started"
			  
        case .unknownResponse(let data, let response):
            let code = (response as? HTTPURLResponse)?.statusCode ?? 600
            let message = String(data: data ?? Data(), encoding: .utf8) ?? "Unparseable Response"
            
            return "\(code): \(message)"
			  
		  case .endOfRepetition: return "No more repetitions"
        }
    }
}
