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
	@MainActor static var screen: CGSize {
		let screen = UIScreen.main
		
		return CGSize(width: screen.bounds.width * screen.scale, height: screen.bounds.height * screen.scale)
	}
}
#endif

extension CGSize {
	var aspectRatio: CGFloat { width / height }
	func scaled(within parent: CGSize, toFit: Bool) -> CGSize {
		guard width > 0, height > 0, parent.width > 0, parent.height > 0 else { return .zero }
		guard toFit else { return parent }
		let scale = min(parent.width / width, parent.height / height)
		return CGSize(width: width * scale, height: height * scale)
	}
}

public struct ImageSize: CustomStringConvertible, Sendable {
	public let width: CGFloat?
	public let height: CGFloat?
	public let tolerance: CGFloat
	public let isMaxSize: Bool
	public let aspectRatio: CGFloat?
	public var toFit = false
	
	public var description: String {
		if let width, let height { return "-\(width)x\(height)"}
		if let aspectRatio { return "-⦛\(aspectRatio)" }
		return ""
	}
	
	public func size(basedOn: CGSize) -> CGSize? {
		if let width, let height { return CGSize(width: width, height: height) }
		if let width {
			return CGSize(width: width, height: width / (basedOn.width / basedOn.height))
		}

		if let height {
			return CGSize(width: height * (basedOn.width / basedOn.height), height: height)
		}
		
		if let aspectRatio {
			if (basedOn.width > basedOn.height) == (aspectRatio <= 1) {
				return CGSize(width: basedOn.height * aspectRatio, height: basedOn.height)
			} else {
				return CGSize(width: basedOn.width, height: basedOn.height / aspectRatio)
			}
		}
		return nil
	}
	
	public init(size: CGSize, tolerance: CGFloat = 1.0, isMaxSize: Bool = true, toFit: Bool = false) {
		self.width = size.width
		self.height = size.height
		self.isMaxSize = isMaxSize
		self.tolerance = tolerance
		self.aspectRatio = nil
		self.toFit = toFit
	}
	
	public init(width: CGFloat? = nil, height: CGFloat? = nil, tolerance: CGFloat = 1.0, isMaxSize: Bool = true, toFit: Bool = false) {
		self.width = width
		self.height = height
		self.isMaxSize = isMaxSize
		self.tolerance = tolerance
		self.aspectRatio = nil
		self.toFit = toFit
	}
	
	public init(aspectRatio: CGFloat, toFit: Bool = false) {
		self.width = nil
		self.height = nil
		self.isMaxSize = false
		self.tolerance = 1.0
		self.aspectRatio = aspectRatio
		self.toFit = toFit
	}
	
	#if os(iOS)
		@MainActor public static var screen: ImageSize {
			ImageSize(size: UIScreen.main.bounds.size, tolerance: 1, isMaxSize: true)
		}
	#endif
	
	public var suffix: String {
		let toFitSuffix = self.toFit ? "-toFit" : ""
		if let aspectRatio { return "_⦛\(aspectRatio)" + toFitSuffix }

		if tolerance == 0 {
			return "_(\(Int(width ?? 0))x\(Int(height ?? 0)))" + toFitSuffix
		}
		return "_(\(Int(width ?? 0))x\(Int(height ?? 0)))±\(Int(tolerance))" + toFitSuffix
	}
	
	func matches(size check: CGSize) -> Bool {
		if let aspectRatio {
			guard check.height > 0 else { return false }
			return abs(check.width / check.height - aspectRatio) <= tolerance
		}

		if isMaxSize {
			if let width, check.width > width + tolerance { return false }
			if let height, check.height > height + tolerance { return false }
			return true
		}
		
		if let width, abs(check.width - width) > tolerance { return false }
		if let height, abs(check.height - height) > tolerance { return false }

		return true
	}
}

#if os(iOS)
extension ImageSize {
	func resize(_ image: UIImage) -> UIImage? {
		if matches(size: image.size) { return image }
		if let limit = size(basedOn: image.size) {
			let outputSize = image.size.scaled(within: limit, toFit: toFit)
			let scale = toFit ? min(outputSize.width / image.size.width, outputSize.height / image.size.height) : max(outputSize.width / image.size.width, outputSize.height / image.size.height)
			let drawnSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
			let drawnRect = CGRect(x: (outputSize.width - drawnSize.width) / 2, y: (outputSize.height - drawnSize.height) / 2, width: drawnSize.width, height: drawnSize.height)
			let format = UIGraphicsImageRendererFormat()
			format.scale = 1
			return UIGraphicsImageRenderer(size: outputSize, format: format).image { _ in
				image.draw(in: drawnRect)
			}
		}
		return image
	}
}
#elseif os(macOS)
extension ImageSize {
	func resize(_ image: NSImage) -> NSImage? {
		if matches(size: image.size) { return image }
		guard let limit = size(basedOn: image.size) else { return image }
		let outputSize = image.size.scaled(within: limit, toFit: toFit)
		let scale = toFit ? min(outputSize.width / image.size.width, outputSize.height / image.size.height) : max(outputSize.width / image.size.width, outputSize.height / image.size.height)
		let drawnSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
		let drawnRect = CGRect(x: (outputSize.width - drawnSize.width) / 2, y: (outputSize.height - drawnSize.height) / 2, width: drawnSize.width, height: drawnSize.height)
		let resized = NSImage(size: outputSize)
		resized.lockFocus()
		image.draw(in: drawnRect, from: .zero, operation: .copy, fraction: 1)
		resized.unlockFocus()
		return resized
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
