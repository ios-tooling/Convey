//
//  ConveyTestApp.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 9/11/21.
//

import SwiftUI

@main
struct ConveyTestApp: App {
	init() {
		Server.serverInstance = Server()
	}

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
