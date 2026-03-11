//
//  HTTPMethod.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/19/25.
//

import Foundation

public enum HTTPMethod: String, Sendable, Codable {
	case get, post, put, patch, delete
}
