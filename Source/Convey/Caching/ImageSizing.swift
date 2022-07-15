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

#if os(iOS)
public extension CGSize {
	static var screen: CGSize {
		let screen = UIScreen.main
		
		return CGSize(width: screen.bounds.width * screen.scale, height: screen.bounds.height * screen.scale)
	}
}
#endif

extension CGSize {
	var aspectRatio: CGFloat { width / height }
	func scaled(within parent: CGSize) -> CGSize {
		if aspectRatio < parent.aspectRatio {
			return CGSize(width: parent.width * (aspectRatio / parent.aspectRatio), height: parent.height)
		} else if aspectRatio < parent.aspectRatio {
			return CGSize(width: parent.width, height: parent.height * (parent.aspectRatio / aspectRatio))
		} else {
			return parent
		}
	}
}

public struct ImageSize {
	public let size: CGSize
	public let tolerance: Double
	public let isMaxSize: Bool
	public var suffix: String {
		if tolerance == 0 {
			return "_(\(Int(size.width))x\(Int(size.height)))"
		}
		return "_(\(Int(size.width))x\(Int(size.height)))±\(Int(tolerance))"
	}
	
	func matches(size check: CGSize) -> Bool {
		if isMaxSize {
			return check.width <= (size.width + tolerance) && check.height <= (size.height + tolerance)
		}
		return check.width >= (size.width - tolerance) && check.width <= (size.width + tolerance) &&
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
		let scaled = image.size.scaled(within: size)
		#if os(iOS)
			return UIGraphicsImageRenderer(size: scaled).image { ctx in
				image.draw(in: CGRect(x: 0, y: 0, width: scaled.width, height: scaled.height))
			}
		#else
			return image
		#endif
	}
}
#endif

public extension ImageSize {
	static func exact(_ double: Double) -> ImageSize {
		ImageSize(size: .init(width: double, height: double), tolerance: 0, isMaxSize: false)
	}

	static func exact(_ int: Int) -> ImageSize {
		ImageSize(size: .init(width: Double(int), height: Double(int)), tolerance: 0, isMaxSize: false)
	}
	
	static func exact(_ size: CGSize) -> ImageSize {
		ImageSize(size: size, tolerance: 0, isMaxSize: false)
	}

	static func about(_ double: Double, tolerance: Double = 10) -> ImageSize {
		ImageSize(size: .init(width: double, height: double), tolerance: tolerance, isMaxSize: false)
	}

	static func about(_ int: Int, tolerance: Double = 10) -> ImageSize {
		ImageSize(size: .init(width: Double(int), height: Double(int)), tolerance: tolerance, isMaxSize: false)
	}

	static func about(_ size: CGSize, tolerance: Double = 10) -> ImageSize {
		ImageSize(size: size, tolerance: tolerance, isMaxSize: false)
	}

	static func less(than size: CGSize, tolerance: Double = 10) -> ImageSize {
		ImageSize(size: size, tolerance: tolerance, isMaxSize: true)
	}

}
