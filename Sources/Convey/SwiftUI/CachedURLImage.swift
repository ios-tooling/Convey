//
//  CachedURLImage.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/20/25.
//


import SwiftUI
import JohnnyCache

#if os(macOS)
//extension NSImage: @unchecked @retroactive Sendable { }
#endif

@available(iOS 15.0, watchOS 8.0, macOS 12.0, *)
@MainActor
public struct CachedURLImage: View {
	@Binding var error: Error?

	let placeholder: Image?
	let imageURL: URL?
	let contentMode: ContentMode
	var showURLs = false
	let imageSize: ImageSize?
	let deferredUntil: Date?
	let renderingMode: Image.TemplateRenderingMode
	
	@State var cachedImage: PlatformImage?
	@State var fetchedURL: URL?
	
	func platformImage(named name: String) -> PlatformImage? {
#if os(macOS)
		return NSImage(named: name)
#else
		return UIImage(named: name)
#endif
	}
	
	public init(url: URL?, contentMode: ContentMode = .fit, placeholder: Image? = nil, showURLs: Bool = false, size: ImageSize? = nil, error: Binding<Error?>? = nil, deferredUntil date: Date? = nil, renderingMode: Image.TemplateRenderingMode = .original) {
		imageURL = url
		_error = error ?? .constant(nil)
		imageSize = size
		deferredUntil = date
		self.contentMode = contentMode
		self.placeholder = placeholder
		self.showURLs = showURLs
		self.renderingMode = renderingMode
	}
	
	var imageView: Image? {
		Image(platformImage: platformImage)?.renderingMode(renderingMode) ?? placeholder?.renderingMode(renderingMode)
	}
	
	var platformImage: PlatformImage? {
		if let cachedImage { return cachedImage }
		
		if cachedImage == nil, let imageURL {
			Task { @MainActor in
				do {
					let image = try await sharedImagesCache[async: imageURL]

					if #available(iOS 16.0, *) {
						if let end = deferredUntil, end > Date() {
							let interval = end.timeIntervalSinceNow
							if interval > 0 {
								try await Task.sleep(nanoseconds: UInt64(Double(1_000_000_000) * interval))
							}
						}
					}
					cachedImage = image
				} catch {
					self.error = error
				}
			}
		}
		
		return nil
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
