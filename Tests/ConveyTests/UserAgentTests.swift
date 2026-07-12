//
//  UserAgentTests.swift
//  Convey
//

import Testing
import Foundation
@testable import Convey

struct UserAgentTests {
	// a NUL (or any control character) in a header value causes strict HTTP parsers like SwiftNIO/Vapor to reject the request outright
	@Test func defaultUserAgentIsSafeForHTTPHeaders() {
		let agent = ServerConfiguration.defaultUserAgent
		let controlScalars = agent.unicodeScalars.filter { CharacterSet.controlCharacters.contains($0) }

		#expect(!agent.isEmpty)
		#expect(controlScalars.isEmpty, "User-Agent contains control characters: \(controlScalars.map { String(format: "U+%04X", $0.value) })")
	}

	@Test func rawDeviceTypeContainsNoControlCharacters() {
		let device = Device.rawDeviceType

		#expect(!device.isEmpty)
		#expect(device.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) })
	}
}
