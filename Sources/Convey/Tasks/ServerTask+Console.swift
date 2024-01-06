//
//  ServerTask+Console.swift
//
//
//  Created by Ben Gottlieb on 1/6/24.
//

import Foundation

public protocol ConsoleDisplayableTask: ServerTask {
	var displayString: String { get }
}

public protocol ConfigurableConsoleDisplayableTask: ConsoleDisplayableTask {
	init(configuration: [String: String])
}

public extension ConsoleDisplayableTask {
	var displayString: String {
		String(describing: type(of: self))
	}
}
