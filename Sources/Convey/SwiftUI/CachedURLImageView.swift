//
//  CachedURLImage.swift
//  
//
//  Created by Ben Gottlieb on 6/5/22.
//

import SwiftUI

@available(iOS 15.0, watchOS 8.0, macOS 12.0, *)
@MainActor
public struct CachedURLImage: View {
	@Binding var error: Error?

	let placeholder: Image?
	let imageURL: URL?
	let contentMode: ContentMode
	var showURLs = false
	let cacheLocation: DataCache.CacheLocation
	let imageSize: ImageSize?
	
	@State var cacheInfo: ImageCache.ImageInfo?
	@State var cachedURL: URL?
	@State var cachedImage: PlatformImage?
	@State var fetchedURL: URL?
	
	func platformImage(named name: String) -> PlatformImage? {
#if os(macOS)
		return NSImage(named: name)
#else
		return UIImage(named: name)
#endif
	}
	
	public init(url: URL?, contentMode: ContentMode = .fit, placeholder: Image? = nil, showURLs: Bool = false, size: ImageSize? = nil, cache: DataCache.CacheLocation = .default, error: Binding<Error?>? = nil) {
		imageURL = url
		self.contentMode = contentMode
		self.placeholder = placeholder
		_error = error ?? .constant(nil)
		self.cacheLocation = cache
		self.showURLs = showURLs
		self.imageSize = size
		
		_cacheInfo = State(initialValue: ImageCache.instance.fetchLocalInfo(for: url, location: cache, size: size))
	}
	
	var imageView: Image? {
		Image(platformImage: platformImage) ?? placeholder
	}
	
	var platformImage: PlatformImage? {
		if cachedURL != imageURL {
			DispatchQueue.main.async { updateCache() }
			return nil
		}
		
		if let image = cacheInfo?.image ?? cachedImage { return image }
		
		if cachedImage == nil, let imageURL {
			Task { @MainActor in
				do {
					cachedImage = try await ImageCache.instance.fetch(from: imageURL, location: cacheLocation, size: imageSize)
				} catch {
					self.error = error
				}
			}
		}
		
		return nil
	}
	
	func updateCache() {
		cachedURL = imageURL
		cacheInfo = ImageCache.instance.fetchLocalInfo(for: imageURL, location: cacheLocation, size: imageSize)
		cachedImage = nil
	}
	
	public var body: some View {
		ZStack() {
			if let imageView {
				imageView
					.resizable()
					.aspectRatio(contentMode: contentMode)
			}
		}
	}
}

@available(iOS 15.0, watchOS 8.0, macOS 12.0, *)
struct SwiftUIView_Previews: PreviewProvider {
	static var previews: some View {
		CachedURLImage(url: URL(string: "https://apod.nasa.gov/apod/image/2205/EclipseRays_Bouvier_1638.jpg"))
	}
}
