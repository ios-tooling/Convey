//
//  URLRequest.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 1/29/22.
//

import Foundation

extension URLRequest {
	var requestTag: String? {
		get { allHTTPHeaderFields?[ServerConstants.Headers.tag] }
		set { setValue(newValue, forHTTPHeaderField: ServerConstants.Headers.tag) }
	}
}
