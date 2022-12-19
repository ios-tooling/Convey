//
//  File.swift
//  
//
//  Created by Ben Gottlieb on 12/19/22.
//

import Foundation

public extension String {
	var linkHeaderDictionary: [String: URL] {
		let components = self.components(separatedBy: ",")
		var results: [String: URL] = [:]
		
		for component in components {
			let pieces = component.components(separatedBy: ";")
			if let url = pieces.first?.headerURL ?? pieces.last?.headerURL, let label = pieces.last?.headerLabel ?? pieces.first?.headerLabel {
				results[label] = url
			}
		}
		return results
	}
}

fileprivate extension String {
	var headerURL: URL? {
		URL(string: trimmingCharacters(in: .init(charactersIn: ";<>")))
	}
	
	var headerLabel: String? {
		let components = trimmingCharacters(in: .whitespaces).components(separatedBy: "=")
		
		if components.count == 2, components[0] == "rel" { return components[1].trimmingCharacters(in: .init(charactersIn: "\"")) }
		return nil
	}
}
