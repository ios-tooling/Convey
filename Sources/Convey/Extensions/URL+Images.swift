//
//  URL+Images.swift
//  
//
//  Created by Ben Gottlieb on 6/27/22.
//

import Foundation
extension URL {
	var cachePathExtension: String? {
		let ext = pathExtension
		if !ext.isEmpty { return ext }
		return nil
	}
}

#if !os(watchOS)
import CoreGraphics
import ImageIO

extension URL {
	func resizedImage(maxSize: CGSize) -> CGImage? {
		resizedImage(maxWidth: maxSize.width, maxHeight: maxSize.height)
	}
	
	func resizedImage(maxWidth: CGFloat? = nil, maxHeight: CGFloat? = nil) -> CGImage? {
		let maxDim = max(maxWidth ?? 0, maxHeight ?? 0)
		if maxDim == 0 {
			let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
			let downsampleOptions = [kCGImageSourceCreateThumbnailFromImageAlways: true] as CFDictionary
			
			guard let imageSource = CGImageSourceCreateWithURL(self as CFURL, imageSourceOptions) else { return nil }
			return CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions)
		}
		return resizedImage(maxDimension: maxDim)
	}
	
	func resizedImage(maxDimension: CGFloat) -> CGImage? {
		let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
		let downsampleOptions =  [kCGImageSourceCreateThumbnailFromImageAlways: true,
								  kCGImageSourceShouldCacheImmediately: true,
								  kCGImageSourceCreateThumbnailWithTransform: true,
								  kCGImageSourceThumbnailMaxPixelSize: maxDimension] as CFDictionary

		guard
			let imageSource = CGImageSourceCreateWithURL(self as CFURL, imageSourceOptions),
			let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions)
		else {
			return nil
		}

		return downsampledImage
	}
}
#endif
