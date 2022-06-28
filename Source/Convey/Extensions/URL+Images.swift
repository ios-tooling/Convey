//
//  URL+Images.swift
//  
//
//  Created by Ben Gottlieb on 6/27/22.
//

#if !os(watchOS)
import Foundation
import CoreGraphics
import ImageIO

extension URL {
	private func resizedImage(maxDimension: CGFloat) -> CGImage? {
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
