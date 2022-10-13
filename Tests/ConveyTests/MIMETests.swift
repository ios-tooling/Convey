//
//  MIMETests.swift
//  
//
//  Created by Ben Gottlieb on 10/13/22.
//

import XCTest
import Convey

extension Bundle {
	static var testBundle: Bundle {
		let url = Bundle(for: MIMETests.self).bundleURL
		return Bundle(url: url.appendingPathComponent("Convey_Convey.bundle"))!
	}
}

final class MIMETests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
		 let components: [MIMEMessageComponent] = [
			.text(name: "field #1", content: "Here is the first field"),
			.image(name: "test image", image: PlatformImage(named: "small_black_square", in: .testBundle, with: nil)!, quality: 0.9)
		 ]

		 let task = SimpleMIMETask(url: URL(string: "http://test.com")!, components: components)
		 
		 let data = task.mimeData(base64Encoded: true)!
		 let text = String(data: data, encoding: .utf8)!
		 print(text)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
