//
//  Data+Reporting.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/21/25.
//

import Foundation

extension Data {

	func reportedData(limit: Int) -> String? {
		// we're going to ignore any errors here. If we can't convert the file to JSON, that's fine
		if count < limit {
			if let json = try? JSONSerialization.jsonObject(with: self) as? [String: Any], let data = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]), let string = String(data: data, encoding: .utf8) {
				return string
			}
			
			return String(data: self, encoding: .utf8)
		}
		
		guard let string = String(data: self[0..<limit], encoding: .utf8) else { return nil }
		let formatter = ByteCountFormatter()
		
		let sizeString = formatter.string(fromByteCount: Int64(count))
		
		return "[total: \(sizeString)]\n" + string + "…"
	}
}
