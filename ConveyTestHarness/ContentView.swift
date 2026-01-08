//
//  ContentView.swift
//  ConveyTestHarness
//
//  Created by Ben Gottlieb on 11/23/24.
//

import SwiftUI
import Suite
import CrossPlatformKit
import Convey
import JohnnyCache

struct ContentView: View {
	@State var image: UXImage?
	@State var index = 0
	@State var totalSize = 0
	@State var fetching = false
	
	init() {
	}
	
	var body: some View {
		VStack() {
			NetworkIndicator()
			
			if #available(iOS 15.0, *) {
				AsyncButton(action: { await fetchNewImage() }) {
					Text("Fetch Image")
				}
				.buttonStyle(.bordered)
			}
			
			Text("Hello, world!")
			if let image = image {
				Image(uxImage: image)
					.resizable()
					.aspectRatio(contentMode: .fit)
					.frame(minWidth: 300, minHeight: 300)
			}
			HStack() {
				Text("Total cache size: \(totalSize)")
				if fetching { ProgressView() }
			}
			
			AsyncButton("Clear Cache") {
				sharedImagesCache.clearAll()
				totalSize = Int(sharedImagesCache.inMemoryCost)
			}
		}
		.onAppear {
			Task {
//				await ConveyTaskReporter.instance.setEnabled(true)
				await fetchNewImage()
				
				let simpleTask = await SimpleGETTask(url: URL(string: "https://www.example.re")!)
				do {
					let result = try await simpleTask/*.echo(.always)*/.download()
					print(result.data.count)
				} catch {
					print("Failed to download: \(error)")
				}
			}
		}
		.padding()
	}
	
	func fetchNewImage() async {
		fetching = true
//		let key = "\(index)"
		index += 1
		let url = URL(string: "https://picsum.photos/\(Int.random(to: 1000))")!
//		image = try? await imageCache.fetch(from: imageCache.provision(url: url), caching: .localFirst)//, location: .grouped("images", key))
		do {
			image = try await sharedImagesCache[async: url]
			print("Fetched \(image, default: "none")")
			totalSize = Int(sharedImagesCache.inMemoryCost)
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
