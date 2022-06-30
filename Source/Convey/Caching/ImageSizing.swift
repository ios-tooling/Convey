//
//  ImageSizing.swift
//  
//
//  Created by Ben Gottlieb on 6/27/22.
//

#if canImport(UIKit)
import UIKit
#endif

#if canImport(Cocoa)
import Cocoa
#endif

public struct ImageSize {
	public let size: CGSize
	public let tolerance: Double
	public var suffix: String {
		if tolerance == 0 {
			return "_(\(Int(size.width))x\(Int(size.height)))"
		}
		return "_(\(Int(size.width))x\(Int(size.height)))±\(Int(tolerance))"
	}
	
	func matches(size check: CGSize) -> Bool {
		check.width >= (size.width - tolerance) && check.width <= (size.width + tolerance) &&
			check.height >= (size.height - tolerance) && check.height <= (size.height + tolerance)
	}
}

#if os(macOS)
extension ImageSize {
	func resize(_ image: NSImage) -> NSImage? {
		return image
	}
}
#else
extension ImageSize {
	func resize(_ image: UIImage) -> UIImage? {
		if matches(size: image.size) { return image }
		#if os(iOS)
			return UIGraphicsImageRenderer(size: size).image { ctx in
				image.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
			}
		#else
			return image
		#endif
	}
}
#endif

public extension ImageSize {
	static func exact(_ double: Double) -> ImageSize {
		ImageSize(size: .init(width: double, height: double), tolerance: 0)
	}

	static func exact(_ int: Int) -> ImageSize {
		ImageSize(size: .init(width: Double(int), height: Double(int)), tolerance: 0)
	}
	
	static func exact(_ size: CGSize) -> ImageSize {
		ImageSize(size: size, tolerance: 0)
	}

	static func about(_ double: Double, tolerance: Double = 10) -> ImageSize {
		ImageSize(size: .init(width: double, height: double), tolerance: tolerance)
	}

	static func about(_ int: Int, tolerance: Double = 10) -> ImageSize {
		ImageSize(size: .init(width: Double(int), height: Double(int)), tolerance: tolerance)
	}

	static func about(_ size: CGSize, tolerance: Double = 10) -> ImageSize {
		ImageSize(size: size, tolerance: tolerance)
	}

}
