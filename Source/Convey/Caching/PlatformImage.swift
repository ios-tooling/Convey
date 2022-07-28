//
//  File.swift
//  
//
//  Created by Ben Gottlieb on 6/27/22.
//

#if os(macOS)
	import Cocoa

	public typealias PlatformImage = NSImage

	extension NSImage {
		var data: Data? { nil }
	}
#else
	import UIKit

	public typealias PlatformImage = UIImage

	extension UIImage {
		var data: Data? { pngData() }
	}
#endif

