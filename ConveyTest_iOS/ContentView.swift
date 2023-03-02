//
//  ContentView.swift
//  ConveyTest_iOS
//
//  Created by Ben Gottlieb on 10/31/21.
//

import SwiftUI
import Suite

struct ContentView: View {
	@State var image: UIImage?
	@State var showBig = false
	var body: some View {
		VStack() {
			Text("Hello, world!")
				.padding()
			
			if let image = image {
				Image(uiImage: image)
			}
			
			Button("Async Test") {
				asyncTest()
			}
			
			if showBig {
				CachedURLImage(url: URL(string: "https://www.learningcontainer.com/bfd_download/large-sample-image-file-download-for-testing/"))
					.frame(height: 200)

				Text("Cache count: \(ImageCache.instance.cacheCount())")
			}
			Button("Show Big") { showBig.toggle() }
		}
		.task {
			do {
				let data = try await ConveyServer.serverInstance.data(for: URL("https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQBt-DSi9AsxGKLFOopQx-DCv4eGGez2Q2nqvLyFdP1s55CLM-MjSik-th2igTc-KFtl34&usqp=CAU"))
				image = UIImage(data: data.data)
			} catch {
				print("Error downloading: \(error)")
			}
			
		}
	}
	
	func asyncTest() {
		for i in 0..<30 {
			Task.detached {
				try? await SampleHTTPBinPOST(index: i).upload()
			}
		}
	}
}

struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		ContentView()
	}
}

