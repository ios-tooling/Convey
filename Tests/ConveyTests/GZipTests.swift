//
//  GZipTests.swift
//  
//
//  Created by Ben Gottlieb on 10/7/22.
//

import XCTest

final class GZipTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testGZipping() throws {
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
		 
		 XCTAssert(base64 == correct)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
