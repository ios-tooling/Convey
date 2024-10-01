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
		DefaultServer.server = ConveyServer()
	}

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
