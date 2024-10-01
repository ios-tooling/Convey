//
//  Test.swift
//  Convey
//
//  Created by Ben Gottlieb on 10/1/24.
//

import Testing
import Convey
import Foundation

struct TestTask: ServerGETTask {
	var path: String { "test" }
	var httpMethod: String { "DELETE" }
	var cookies: [HTTPCookie] { [HTTPCookie(properties: [.domain: "test.com", .path: "/", .name: "test", .value: "test"])!] }
}

struct Test {

    @Test func TestTaskMethods() async throws {
		 let task = TestTask()
		 
		 #expect(task.httpMethod == "DELETE" )
		 #expect(task.cookies.count == 1)
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

}
