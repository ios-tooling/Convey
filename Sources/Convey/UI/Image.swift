//
//  Image.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/20/25.
//


import SwiftUI


extension Image {
	#if os(OSX)
		init?(platformImage: NSImage?) {
			guard let platformImage else { return nil }
			self.init(nsImage: platformImage)
		}
	#else
		init?(platformImage: UIImage?) {
			guard let platformImage else { return nil }
			self.init(uiImage: platformImage)
		}
	#endif

}
