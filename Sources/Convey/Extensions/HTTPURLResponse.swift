//
//  HTTPURLResponse.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 6/5/23.
//

import Foundation


//  Link: <https://iosdev.space/api/v1/timelines/public?max_id=110490905973621111>; rel="next", <https://iosdev.space/api/v1/timelines/public?min_id=110490928963061023>; rel="prev"

public extension HTTPURLResponse {
	struct Link: Codable, Sendable {
		public var url: URL
		public var fields: [Field]
		
		public struct Field: Codable, Sendable {
			public let label: String			// it appears that this is *usually* "rel"
			public let value: String
			
			init?(string: String) {
				let comp = string.components(separatedBy: "=")
				guard comp.count == 2 else { return nil }
				label = comp[0]
				value = comp[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
			}
		}
		
		init?(string: String) {
			let comp = string.components(separatedBy: ";")
			guard !comp.isEmpty, let url = URL(string: comp[0].trimmingCharacters(in: .init(charactersIn: "<>"))) else { return nil }
			
			self.url = url
			self.fields = comp.dropFirst().compactMap { Field(string: $0) }
		}
	}
	
	var links: [Link] {
		guard let header = value(forHTTPHeaderField: "Link") else { return [] }
		
		return header.components(separatedBy: ",").compactMap {
			Link(string: $0.trimmingCharacters(in: .whitespaces))
		}
	}
	
	func linkURL(for field: String) -> URL? {
		links.first { $0.fields.contains(where: { $0.value == field })}?.url
	}
	
	var data: Data {
		get throws { try NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: true) }
	}
	
	func write(to file: URL) throws {
		try data.write(to: file)
	}
	
	class func load(from data: Data) throws -> HTTPURLResponse? {
		try NSKeyedUnarchiver.unarchivedObject(ofClass: HTTPURLResponse.self, from: data)
	}
		
	class func load(from file: URL) throws -> HTTPURLResponse? {
		let responseData = try Data(contentsOf: file)
		return try load(from: responseData)
	}
	
}
