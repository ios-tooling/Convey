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
	public let width: CGFloat?
	public let height: CGFloat?
	public let tolerance: CGFloat
	public let isMaxSize: Bool
	
	public func size(basedOn: CGSize) -> CGSize? {
		if let width, let height { return CGSize(width: width, height: height) }
		if let width {
			return CGSize(width: width, height: width / (basedOn.width / basedOn.height))
		}

		if let height {
			return CGSize(width: height * (basedOn.width / basedOn.height), height: height)
		}
		return nil
	}
	
	public init(size: CGSize, tolerance: CGFloat = 1.0, isMaxSize: Bool = true) {
		self.width = size.width
		self.height = size.height
		self.isMaxSize = isMaxSize
		self.tolerance = tolerance
	}
	
	public init(width: CGFloat? = nil, height: CGFloat? = nil, tolerance: CGFloat = 1.0, isMaxSize: Bool = true) {
		self.width = width
		self.height = height
		self.isMaxSize = isMaxSize
		self.tolerance = tolerance
	}
	
	#if os(iOS)
		public static var screen: ImageSize {
			ImageSize(size: UIScreen.main.bounds.size, tolerance: 1, isMaxSize: true)
		}
	#endif
	
	public var suffix: String {
		if tolerance == 0 {
			return "_(\(Int(width ?? 0))x\(Int(height ?? 0)))"
		}
		return "_(\(Int(width ?? 0))x\(Int(height ?? 0)))±\(Int(tolerance))"
	}
	
	func matches(size check: CGSize) -> Bool {
		if isMaxSize {
			if let width, width > check.width + tolerance { return false }
			if let height, height > check.height + tolerance { return false }
			return true
		}
		
		if let width, width < check.width - tolerance { return false }
		if let height, height < check.width - tolerance { return false }

		return true
	}
}

#if os(iOS)
extension ImageSize {
	func resize(_ image: UIImage) -> UIImage? {
		if matches(size: image.size) { return image }
		if let limit = size(basedOn: image.size) {
			let scaled = image.size.scaled(within: limit)
			return UIGraphicsImageRenderer(size: scaled).image { ctx in
				image.draw(in: CGRect(x: 0, y: 0, width: scaled.width, height: scaled.height))
			}
		}
		return image
	}
}
#elseif os(macOS)
extension ImageSize {
	func resize(_ image: NSImage) -> NSImage? {
		return image
	}
}
#else
extension ImageSize {
	func resize(_ image: UIImage) -> UIImage? {
		return image
	}
}
#endif

public extension ImageSize {
	static func exact(_ double: CGFloat) -> ImageSize {
		ImageSize(size: .init(width: double, height: double), tolerance: 0, isMaxSize: false)
	}

	static func exact(_ int: Int) -> ImageSize {
		ImageSize(size: .init(width: CGFloat(int), height: CGFloat(int)), tolerance: 0, isMaxSize: false)
	}
	
	static func exact(_ size: CGSize) -> ImageSize {
		ImageSize(size: size, tolerance: 0, isMaxSize: false)
	}

	static func about(_ double: CGFloat, tolerance: CGFloat = 10) -> ImageSize {
		ImageSize(size: .init(width: double, height: double), tolerance: tolerance, isMaxSize: false)
	}

	static func about(_ int: Int, tolerance: CGFloat = 10) -> ImageSize {
		ImageSize(size: .init(width: CGFloat(int), height: CGFloat(int)), tolerance: tolerance, isMaxSize: false)
	}

	static func about(_ size: CGSize, tolerance: CGFloat = 10) -> ImageSize {
		ImageSize(size: size, tolerance: tolerance, isMaxSize: false)
	}

	static func less(than size: CGSize, tolerance: CGFloat = 10) -> ImageSize {
		ImageSize(size: size, tolerance: tolerance, isMaxSize: true)
	}

}
