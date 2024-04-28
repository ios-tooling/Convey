//
//  ConveyTest_iOSApp.swift
//  ConveyTest_iOS
//
//  Created by Ben Gottlieb on 10/31/21.
//

import SwiftUI

@main
struct ConveyTest_iOSApp: App {
	init() {
		ConveyServer.serverInstance = ConveyServer()
		ConveyServer.serverInstance.taskManager.setIsEnabled()
		
		Task { await Self.testLinks() }
	}
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
	
	static func testLinks() async {
		let data = try! await SimpleGETTask(url: URL("https://iosdev.space/api/v1/timelines/public"))
			.preview { preview in
			}
			//.echoes(true)
			.downloadDataWithResponse()
		
		let links = data.response.links
		print(links)
		
		let prev = data.response.linkURL(for: "prev")
		print(prev!)
	}
}
