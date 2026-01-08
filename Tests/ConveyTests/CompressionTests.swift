//
//  CompressionTests.swift
//  Convey
//
//  Created by Claude Code
//

import Testing
import Foundation
@testable import Convey

@Suite("GZip Compression")
struct CompressionTests {

	@Test("Data can be gzipped")
	func testGzipCompression() throws {
		let originalString = "Hello, World! This is a test string for compression. It's quite long, and has a little bit of repeating content, I say, repeating content"
		let originalData = originalString.data(using: .utf8)!

		let compressed = try originalData.gzipped()
		print(compressed.count, originalData.count)
		#expect(compressed.count > 0, "Compressed data should not be empty")
		#expect(compressed.count < originalData.count, "Compressed data should be smaller than original")
	}

	@Test("Gzipped data can be gunzipped")
	func testGzipRoundTrip() throws {
		let originalString = "Hello, World! This is a test string for compression and decompression."
		let originalData = originalString.data(using: .utf8)!

		let compressed = try originalData.gzipped()
		let decompressed = try compressed.gunzipped()

		#expect(decompressed == originalData, "Decompressed data should match original")

		if let decompressedString = String(data: decompressed, encoding: .utf8) {
			#expect(decompressedString == originalString, "Decompressed string should match original")
		} else {
			Issue.record("Failed to decode decompressed data as UTF-8")
		}
	}

	@Test("JSON data compression")
	func testJSONCompression() throws {
		let json = """
		{
			"field_1": 7,
			"field_2": "Hello",
			"field_3": {
				"nested": "value",
				"array": [1, 2, 3, 4, 5]
			}
		}
		"""

		let data = json.data(using: .utf8)!
		let compressed = try data.gzipped()

		#expect(compressed.count < data.count, "Compressed JSON should be smaller")

		let decompressed = try compressed.gunzipped()
		#expect(decompressed == data, "Decompressed JSON should match original")
	}

	@Test("Specific JSON compression matches expected output")
	func testSpecificJSONCompression() throws {
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

		#expect(base64 == correct, "Compressed data should match expected base64")
	}

	@Test("Empty data compression")
	func testEmptyDataCompression() throws {
		let emptyData = Data()

		let compressed = try emptyData.gzipped()

		#expect(compressed.count > 0, "Even empty data should have gzip header")

		let decompressed = try compressed.gunzipped()
		#expect(decompressed.isEmpty, "Decompressed empty data should be empty")
	}

	@Test("Large data compression")
	func testLargeDataCompression() throws {
		// Create a large repetitive string (compresses well)
		let pattern = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
		let large = String(repeating: pattern, count: 1000)
		let largeData = large.data(using: .utf8)!

		let compressed = try largeData.gzipped()

		#expect(compressed.count > 0, "Compressed data should not be empty")
		#expect(compressed.count < largeData.count, "Compressed data should be much smaller than original")

		// Compression ratio should be significant for repetitive data
		let ratio = Double(compressed.count) / Double(largeData.count)
		#expect(ratio < 0.1, "Compression ratio should be < 10% for repetitive data, got \(ratio)")

		let decompressed = try compressed.gunzipped()
		#expect(decompressed == largeData, "Decompressed data should match original")
	}

	@Test("Random data compression is less effective")
	func testRandomDataCompression() throws {
		// Random data doesn't compress well
		var randomData = Data(count: 1000)
		randomData.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) in
			for i in 0..<1000 {
				buffer[i] = UInt8.random(in: 0...255)
			}
		}

		let compressed = try randomData.gzipped()

		// Random data might actually be larger after compression
		#expect(compressed.count > 0, "Compressed data should not be empty")

		let decompressed = try compressed.gunzipped()
		#expect(decompressed == randomData, "Decompressed data should match original")
	}

	@Test("Compression with different levels")
	func testCompressionLevels() throws {
		let testString = String(repeating: "Test data for compression levels. ", count: 100)
		let testData = testString.data(using: .utf8)!

		let defaultCompressed = try testData.gzipped()
		let fastCompressed = try testData.gzipped(level: .bestSpeed)
		let bestCompressed = try testData.gzipped(level: .bestCompression)

		#expect(defaultCompressed.count > 0, "Default compression should work")
		#expect(fastCompressed.count > 0, "Fast compression should work")
		#expect(bestCompressed.count > 0, "Best compression should work")

		// Best compression should be smallest or equal
		#expect(bestCompressed.count <= defaultCompressed.count,
				"Best compression should be <= default")

		// All should decompress correctly
		let decompressed1 = try defaultCompressed.gunzipped()
		let decompressed2 = try fastCompressed.gunzipped()
		let decompressed3 = try bestCompressed.gunzipped()

		#expect(decompressed1 == testData, "Default decompression should work")
		#expect(decompressed2 == testData, "Fast decompression should work")
		#expect(decompressed3 == testData, "Best decompression should work")
	}

	@Test("isGzipped detection")
	func testIsGzippedDetection() throws {
		let regularData = "Not compressed".data(using: .utf8)!
		let compressedData = try regularData.gzipped()

		#expect(compressedData.isGzipped, "Compressed data should be detected as gzipped")
		#expect(!regularData.isGzipped, "Regular data should not be detected as gzipped")
	}

	@Test("Multiple compression/decompression cycles")
	func testMultipleCycles() throws {
		var data = "Original data for multiple cycles".data(using: .utf8)!
		let original = data

		// Compress and decompress multiple times
		for _ in 0..<5 {
			data = try data.gzipped()
			data = try data.gunzipped()
		}

		#expect(data == original, "Data should remain unchanged after multiple cycles")
	}

	@Test("Binary data compression")
	func testBinaryDataCompression() throws {
		// Create binary data (not UTF-8 text)
		var binaryData = Data(count: 500)
		binaryData.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) in
			for i in 0..<500 {
				buffer[i] = UInt8(i % 256)
			}
		}

		let compressed = try binaryData.gzipped()
		let decompressed = try compressed.gunzipped()

		#expect(decompressed == binaryData, "Binary data should decompress correctly")
	}

	@Test("Window bits parameter")
	func testWindowBits() throws {
		let data = "Test data for window bits".data(using: .utf8)!

		// Test with max window bits
		let compressed = try data.gzipped(wBits: Gzip.maxWindowBits)
		let decompressed = try compressed.gunzipped()

		#expect(decompressed == data, "Should work with max window bits")
	}

	@Test("GZip task configuration")
	func testGZipTaskConfiguration() async throws {
		@ConveyActor
		class TestServer: ConveyServerable {
			var remote = Remote(URL(string: "https://httpbin.org")!, name: "Test")
			var configuration = ServerConfiguration()

			nonisolated init() {
			}

			func headers(for task: any DownloadingTask) async throws -> Headers {
				configuration.defaultHeaders
			}

			func didFinish<T>(task: T, response: ServerResponse<Data>?, error: (any Error)?) async where T : DownloadingTask {
			}

			func configure() {
				configuration.enableGZipDownloads = true
				configuration.enableGZipUploads = false
			}
		}

		let server = TestServer()
		await Task { @ConveyActor in
			server.configure()
		}.value

		let gzipDownloads = await Task { @ConveyActor in
			server.configuration.enableGZipDownloads
		}.value

		let gzipUploads = await Task { @ConveyActor in
			server.configuration.enableGZipUploads
		}.value

		#expect(gzipDownloads == true, "GZip downloads should be enabled")
		#expect(gzipUploads == false, "GZip uploads should be disabled by default")
	}

	@Test("Compression error handling - invalid gzipped data")
	func testInvalidGzippedData() throws {
		let invalidData = "Not actually gzipped".data(using: .utf8)!

		#expect(throws: Error.self) {
			_ = try invalidData.gunzipped()
		}
	}

	@Test("Compression preserves data integrity")
	func testDataIntegrity() throws {
		// Test various data types
		let testCases = [
			"Simple ASCII text",
			"Unicode: 你好世界 🌍",
			String(repeating: "A", count: 1000),
			"Mixed: ABC123!@#$%^&*()",
			"",
			" ",
			"\n\r\t"
		]

		for testCase in testCases {
			let data = testCase.data(using: .utf8)!
			let compressed = try data.gzipped()
			let decompressed = try compressed.gunzipped()

			#expect(decompressed == data, "Failed for test case: \(testCase)")
		}
	}
}
