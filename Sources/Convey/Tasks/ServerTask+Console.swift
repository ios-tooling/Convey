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

public struct ConsoleConfigurationField: Identifiable, Sendable {
	public let id = UUID()
	public enum Kind: Sendable { case string, integer }
	public let label: String
	public let kind: Kind
	public let defaultValue: String?
	
	public init(label: String, kind: Kind = .string, defaultValue: String? = nil) {
		self.label = label
		self.kind = kind
		self.defaultValue = defaultValue
	}
}

public protocol ConfigurableConsoleDisplayableTask: ConsoleDisplayableTask {
	init?(configuration: [String: String])
	static var configurationFields: [ConsoleConfigurationField] { get }
}

public extension ConsoleDisplayableTask {
	var displayString: String {
		String(describing: type(of: self))
	}
}
