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
	}
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
