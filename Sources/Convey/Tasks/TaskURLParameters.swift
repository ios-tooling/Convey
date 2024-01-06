//
//  TaskURLParameters.swift
//  
//
//  Created by Ben Gottlieb on 1/5/24.
//

import Foundation

public protocol TaskURLParameters {
	var isEmpty: Bool { get }
}

extension Dictionary: TaskURLParameters where Key == String, Value == String { }
extension Array: TaskURLParameters where Element == URLQueryItem { }
