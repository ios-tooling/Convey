//
//  StringTests.swift
//  
//
//  Created by Ben Gottlieb on 12/19/22.
//

import XCTest
import Convey

final class StringTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

	func testExample() throws {
		let string = "<https://mastodon.social/api/v1/accounts/2384/following?max_id=27921931>; rel=\"next\""

		let url = string.linkHeaderDictionary["next"]
		XCTAssert(url != nil)
	}

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
