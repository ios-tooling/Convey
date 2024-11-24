//
//  File.swift
//  Convey
//
//  Created by Ben Gottlieb on 11/24/24.
//

import Foundation

extension Data {
	var prettyJSON: String? {
		guard let object = try? JSONSerialization.jsonObject(with: self) else { return nil }
		
		guard let raw = try? JSONSerialization.data(withJSONObject: object, options: .prettyPrinted) else { return nil }
		let string = String(data: raw, encoding: .utf8)
		return string
		//?.replacingOccurrences(of: "\\/", with: "/")
	}
}
