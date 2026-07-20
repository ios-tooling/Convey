//
//  GZipTests.swift
//  
//
//  Created by Ben Gottlieb on 10/7/22.
//

import Foundation
import Testing
@testable import Convey

@Suite("GZip")
struct GZipTests {
	@Test("Data is gzipped deterministically")
	func gzipping() throws {
		 let raw = """
{
	"field_1": 7,
	"field_2": "Hello"

}
"""
		 let data = raw.data(using: .utf8)!
		 let compressed = try data.gzipped()
		 let base64 = compressed.base64EncodedString()
		 let correct = "H4sIAAAAAAAAE6vm4lRKy0zNSYk3VLJSMNeBc42AXCWP1JycfCUurloAFUqXuicAAAA="
		 
		 #expect(base64 == correct)
	}
}
