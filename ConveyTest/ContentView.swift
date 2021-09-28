//
//  ContentView.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 9/11/21.
//

import SwiftUI
import Suite

struct ContentView: View {
    var body: some View {
		 VStack() {
			 NetworkIndicator()
			 Text("Hello, world!")
		 }
		.padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct NetworkIndicator: View {
	@ObservedObject var reachability = Reachability.instance
	
	var body: some View {
		Text(reachability.connection.description)
	}
}
