//
//  Image.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 4/22/23.
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
