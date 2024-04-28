//
//  ContentView.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 9/11/21.
//

import SwiftUI
import Suite

@MainActor
struct ContentView: View {
	@State var image: NSImage?
	@State var index = 0
	@State var totalSize = 0
	@State var fetching = false
	let imageCache = ImageCache.instance
	
	init() {
		Task { await ImageCache.instance.setCacheLimit(1_000_000 / 3) }
	}
	
	var body: some View {
		VStack() {
			NetworkIndicator()
			Text("Hello, world!")
			if let image = image {
				Image(nsImage: image)
					.resizable()
					.aspectRatio(contentMode: .fit)
					.frame(minWidth: 300, minHeight: 300)
			}
			HStack() {
				Text("Total cache size: \(totalSize)")
				if fetching { ProgressView() }
			}
			
			AsyncButton("Clear Cache") {
				await ImageCache.instance.prune(location: .grouped("images", nil))
				totalSize = await imageCache.fetchTotalSize()
			}
		}
		.onTapGesture() {
			Task { await fetchNewImage() }
		}
		.task {
			await fetchNewImage()
		}
		.padding()
	}
	
	func fetchNewImage() async {
		fetching = true
		//let key = "\(index)"
		index += 1
		let url = URL("https://source.unsplash.com/user/c_v_r/500x500")
		//image = try? await imageCache.fetch(from: imageCache.provision(url: url), caching: .localFirst, location: .grouped("images", key))
		do {
			image = try await imageCache.fetch(from: imageCache.provision(url: url))
			totalSize = await imageCache.fetchTotalSize()
		} catch {
			print("Failed to fetch image: \(error)")
		}
		fetching = false
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
