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
	var body: some View {
		VStack() {
			Text("Hello, world!")
				.padding()
			
			if let image = image {
				Image(uiImage: image)
			}
		}
		.task {
			do {
				let data = try await Server.serverInstance.data(for: URL("https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQBt-DSi9AsxGKLFOopQx-DCv4eGGez2Q2nqvLyFdP1s55CLM-MjSik-th2igTc-KFtl34&usqp=CAU"))
				image = UIImage(data: data.data)
			} catch {
				print("Error downloading: \(error)")
			}
			
		}
	}
}

struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		ContentView()
	}
}
