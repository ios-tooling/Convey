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
	let placeholder: Image?
	let imageURL: URL?
	let contentMode: ContentMode
	var showURLs = false
	let errorCallback: ((Error?) -> Void)?
	let cacheLocation: DataCache.CacheLocation
	@State var platformImage: PlatformImage?
	@State var fetchedURL: URL?
	@State var localURL: URL?
	let imageSize: ImageSize?
	private var initialFetch: ImageCache.ImageInfo?
	
	func platformImage(named name: String) -> PlatformImage? {
#if os(macOS)
		return NSImage(named: name)
#else
		return UIImage(named: name)
#endif
	}
	
	public init(url: URL?, contentMode: ContentMode = .fit, placeholder: Image? = nil, showURLs: Bool = false, size: ImageSize? = nil, cache: DataCache.CacheLocation = .default, errorCallback: ((Error?) -> Void)? = nil) {
		imageURL = url
		self.contentMode = contentMode
		self.placeholder = placeholder
		self.errorCallback = errorCallback
		self.cacheLocation = cache
		self.showURLs = showURLs
		self.imageSize = size
		if let url = url {
			initialFetch = ImageCache.instance.fetchLocalInfo(for: url, location: cache, size: size)
			_localURL = State(initialValue: initialFetch?.localURL)
			if let image = initialFetch?.image {
				_platformImage = State(initialValue: image)
			}
		}
	}
	
	var imageView: Image? {
		if let image = platformImage {
#if os(OSX)
			return Image(nsImage: image)
#else
			return Image(uiImage: image)
#endif
		}
		
		if let placeholder = placeholder { return placeholder }
		return nil
	}
	
	public var body: some View {
		ZStack() {
			if let imageView = imageView {
				imageView
					.resizable()
					.aspectRatio(contentMode: contentMode)
			}
			if showURLs {
				VStack() {
					if let url = localURL {
						Text(url.lastPathComponent)
							.foregroundColor(platformImage == nil ? .red : .white)
							.background(Color.black)
					}

					if let url = imageURL {
						Text(url.absoluteString)
							.foregroundColor(.orange)
					}

//					if let location = fetchedURL {
//						Text(location.path)
//							.foregroundColor(.yellow)
//					}
				}
				.font(.caption)
				.padding()
			//	.background(RoundedRectangle(cornerRadius: 5).fill(Color.black))
			}
		}
		.task() {
			guard let url = imageURL, url != fetchedURL else { return }
			if let image = ImageCache.instance.fetchLocal(for: url, location: cacheLocation, size: imageSize) {
				platformImage = image
				fetchedURL = url
			}
			
			if let imageURL = imageURL, platformImage == nil {
				do {
					platformImage = try await ImageCache.instance.fetch(from: imageURL, location: cacheLocation, size: imageSize)
					fetchedURL = url
				} catch {
					errorCallback?(error)
				}
			}
		}
		.id(imageURL?.absoluteString ?? "--")
	}
	
}

@available(iOS 15.0, watchOS 8.0, macOS 12.0, *)
struct SwiftUIView_Previews: PreviewProvider {
	static var previews: some View {
		CachedURLImage(url: URL(string: "https://apod.nasa.gov/apod/image/2205/EclipseRays_Bouvier_1638.jpg"))
	}
}
