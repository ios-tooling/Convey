//
//  CommandLine.swift
//  
//
//  Created by Ben Gottlieb on 9/8/22.
//

import Foundation

extension CommandLine: @unchecked Sendable { }

extension CommandLine {
	static func sendableArguments() -> [String] {
		UnsafeBufferPointer<UnsafeMutablePointer<CChar>?>(
		  start: CommandLine.unsafeArgv,
		  count: Int(CommandLine.argc)
		).lazy
		  .compactMap { $0 }
		  .compactMap { String(validatingUTF8: $0) }
	}
	
	static func bool(for key: String) -> Bool {
		if let string = self.string(for: key)?.lowercased() {
			return string == "y" || string == "yes" || string == "true"
		}
		
		return false
	}

	static func string(for key: String) -> String? {
		let punct = CharacterSet.punctuationCharacters
		for arg in sendableArguments() {
			let comps = arg.components(separatedBy: "=")
			if comps.count < 2 { continue }
			
			if comps[0].trimmingCharacters(in: punct) == key { return Array(comps.dropFirst()).joined(separator: "=").trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
		}
		return nil
	}
}

extension ProcessInfo {
	static func bool(for key: String) -> Bool {
		if let string = self.string(for: key)?.lowercased() {
			return string == "y" || string == "yes" || string == "true"
		}
		
		return false
	}
	
	static func string(for key: String) -> String? {
		ProcessInfo.processInfo.environment[key]
	}
}
