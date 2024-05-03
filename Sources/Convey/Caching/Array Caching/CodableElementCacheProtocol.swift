//
//  CodableElementCacheProtocol.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 4/28/24.
//

import Foundation
import Combine

protocol CodableElementCacheProtocol<DownloadedElement>: Actor, ObservableObject {
	associatedtype DownloadedElement: CacheableElement
	
	func load(items newItems: [DownloadedElement])
	func refresh() async throws
	func refresh<NewDownloader: PayloadDownloadingTask>(from task: NewDownloader) async throws -> Void where NewDownloader.DownloadPayload: WrappedDownloadArray, NewDownloader.DownloadPayload.Element == DownloadedElement
	
	nonisolated func clear()
	nonisolated func setup()
	nonisolated var items: [DownloadedElement] { get }
	var cacheName: String? { get }
	var fileWatcher: FileWatcher? { get set }
}

extension CodableElementCacheProtocol {
	var cacheName: String? { String(describing: DownloadedElement.self) + "_cache.json" }
	
	func setupRedirect(_ redirect: TaskRedirect?) {
		guard let redirect else { return }
		
		print("Setting up redirect for \(String(describing: DownloadedElement.self)) to \(redirect)")
		if let url = redirect.dataURL {
			fileWatcher?.finish()
			fileWatcher = try? FileWatcher(url: url, changed: { _ in
				Task { try? await self.refresh() }
			})
		}
	}
	
	var cacheLocation: URL? {
		guard let cacheName else { return nil }
		return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent(cacheName)
	}
	
	func saveToCache() throws {
		guard let cacheLocation else { return }
		let data = try JSONEncoder().encode(items)
		try data.write(to: cacheLocation, options: .atomic)
	}
	
	nonisolated func setup() { }
	func loadFromCache() {
		guard let cacheLocation else { return }
		do {
			let data = try Data(contentsOf: cacheLocation)
			let items = try JSONDecoder().decode([DownloadedElement].self, from: data)
			load(items: items)
		} catch {
			let ns = error as NSError
			if ns.domain == NSCocoaErrorDomain, ns.code == 260 { return }
			print("Failed to load \(DownloadedElement.self) from \(cacheLocation.path): \(error)")
		}
	}
}
