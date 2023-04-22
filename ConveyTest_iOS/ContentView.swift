//
//  ContentView.swift
//  ConveyTest_iOS
//
//  Created by Ben Gottlieb on 10/31/21.
//

import SwiftUI
import Suite

let landscape = URL(string: "https://www.learningcontainer.com/bfd_download/large-sample-image-file-download-for-testing/")!

let enterprise = URL("https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQBt-DSi9AsxGKLFOopQx-DCv4eGGez2Q2nqvLyFdP1s55CLM-MjSik-th2igTc-KFtl34&usqp=CAU")


struct ContentView: View {
	@State var image: UIImage?
	@State var showBig = false
	@State var imageURL = enterprise
	
	var body: some View {
		VStack() {
			Text("Hello, world!")
				.padding()
			
			CachedURLImage(url: imageURL)
				.onTapGesture {
					imageURL = (imageURL == enterprise) ? landscape : enterprise
				}
			
			Button("Async Test") {
				asyncTest()
			}
			
			if showBig {
				CachedURLImage(url: imageURL)
					.frame(height: 200)

				Text("Cache count: \(ImageCache.instance.cacheCount())")
			}
			Button("Show Big") { showBig.toggle() }
		}
		.task {
			do {
				let data = try await ConveyServer.serverInstance.data(for: landscape)
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

