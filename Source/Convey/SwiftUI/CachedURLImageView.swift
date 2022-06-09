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
	let errorCallback: ((Error?) -> Void)?
	@State var platformImage: PlatformImage?
	@State var fetchedURL: URL?
	
	func platformImage(named name: String) -> PlatformImage? {
		#if os(macOS)
			return NSImage(named: name)
		#else
			return UIImage(named: name)
		#endif
	}
	
	public init(url: URL?, contentMode: ContentMode = .fit, placeholder: Image? = nil, errorCallback: ((Error?) -> Void)? = nil) {
		imageURL = url
		self.contentMode = contentMode
		self.placeholder = placeholder
		self.errorCallback = errorCallback
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
		HStack() {
			if let imageView = imageView {
				imageView
					.resizable()
					.aspectRatio(contentMode: contentMode)
			}
		}
		.task() {
			guard let url = imageURL, url != fetchedURL else { return }
			if let image = await ImageCache.instance.fetchLocal(for: url) {
				platformImage = image
				fetchedURL = url
			}

			if let imageURL = imageURL, platformImage == nil {
				do {
					platformImage = try await ImageCache.instance.fetch(from: imageURL)
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
