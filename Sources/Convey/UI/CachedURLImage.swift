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
		Image(platformImage: cachedImage)?.renderingMode(renderingMode) ?? placeholder?.renderingMode(renderingMode)
	}
	
	public var body: some View {
		ZStack(alignment: .bottom) {
			if let imageView {
				imageView
					.resizable()
					.aspectRatio(contentMode: contentMode)
			}
			if showURLs, let imageURL {
				Text(imageURL.absoluteString)
					.font(.caption2)
					.lineLimit(1)
			}
		}
		.task(id: imageURL) {
			await loadImage()
		}
	}

	private func loadImage() async {
		cachedImage = nil
		error = nil
		guard let imageURL else { return }
		do {
			guard let image = try await sharedImagesCache[async: imageURL] else { return }
			if let end = deferredUntil, end > Date() {
				let delay = max(0, end.timeIntervalSinceNow)
				try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
			}
			try Task.checkCancellation()
			cachedImage = imageSize?.resize(image) ?? image
		} catch is CancellationError {
			// A URL change cancels the previous load; no user-visible error.
		} catch {
			self.error = error
		}
	}
}

@available(iOS 15.0, watchOS 8.0, macOS 12.0, *)
struct SwiftUIView_Previews: PreviewProvider {
	static var previews: some View {
		CachedURLImage(url: URL(string: "https://apod.nasa.gov/apod/image/2205/EclipseRays_Bouvier_1638.jpg"))
	}
}
