//
//  File.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/20/25.
//

#if os(macOS)
	import Cocoa
	import AppKit

	public typealias PlatformImage = NSImage

	extension NSImage {
		var data: Data? { nil }
		
		func jpegData(compressionQuality: Double) -> Data? {
			nil
		}
	}
#else
	import UIKit

	public typealias PlatformImage = UIImage

	extension UIImage {
		var data: Data? { pngData() }
	}
#endif

