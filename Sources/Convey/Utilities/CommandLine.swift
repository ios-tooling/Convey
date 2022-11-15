//
//  CommandLine.swift
//  
//
//  Created by Ben Gottlieb on 9/8/22.
//

import Foundation

extension CommandLine {
	static func bool(for key: String) -> Bool {
		if let string = self.string(for: key)?.lowercased() {
			return string == "y" || string == "yes" || string == "true"
		}
		
		return false
	}

	static func string(for key: String) -> String? {
		let punct = CharacterSet.punctuationCharacters
		for arg in self.arguments {
			let comps = arg.components(separatedBy: "=")
			if comps.count < 2 { continue }
			
			if comps[0].trimmingCharacters(in: punct) == key { return Array(comps.dropFirst()).joined(separator: "=").trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
		}
		return nil
	}
}
