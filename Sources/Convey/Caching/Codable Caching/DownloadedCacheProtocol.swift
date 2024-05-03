//
//  CodableElementCacheProtocol.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 4/28/24.
//

import Foundation
import Combine

#if canImport(UIKit)
	import UIKit
#endif

protocol DownloadedCacheProtocol<DownloadedItem>: Actor, ObservableObject {
	associatedtype DownloadedItem: CacheableElement
	typealias UpdateClosure = (() async throws -> DownloadedItem)

	func load(_ new: DownloadedItem?)
	func refresh() async throws

	nonisolated func clear()
	nonisolated func setup()
	
	nonisolated var content: DownloadedItem? { get }
	var cacheName: String? { get }
	var fileWatcher: FileWatcher? { get set }
	var notificationObservers: [Any] { get set }
	var updateClosure: UpdateClosure? { get set }
}

protocol DownloadedArrayCacheProtocol<DownloadedElement>: DownloadedCacheProtocol where DownloadedItem == [DownloadedElement] {
	associatedtype DownloadedElement: CacheableElement
	
	var items: [DownloadedElement] { get }
}

extension DownloadedCacheProtocol {
	var cacheName: String? { String(describing: DownloadedItem.self) + "_cache.json" }
	
	func setupRedirect(_ redirect: TaskRedirect?) {
		guard let redirect else { return }
		
		print("Setting up redirect for \(String(describing: DownloadedItem.self)) to \(redirect)")
		if let url = redirect.dataURL {
			fileWatcher?.finish()
			fileWatcher = try? FileWatcher(url: url, changed: { _ in
				Task { try? await self.refresh() }
			})
		}
	}
	
	nonisolated func updateRefreshment(redirect: TaskRedirect?, refresh: CacheRefreshTiming) {
		Task {
			await setupRedirect(redirect)
			await loadFromCache()
			if refresh.contains(.atStartup) { try? await self.refresh() }
			#if os(iOS)
				if refresh.contains(.atResume) { await self.refresh(on: UIApplication.didBecomeActiveNotification) }
			#endif

			if refresh.contains(.atSignIn) { self.refresh(on: .conveyDidSignInNotification) }
			if refresh.contains(.atSignOut) { self.refresh(on: .conveyDidSignOutNotification) }
		}
	}
	
	func addObserver(_ observer: Any) { notificationObservers.append(observer) }
	nonisolated func refresh(on name: Notification.Name) {
		Task { await addObserver(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main, using: { note in self.nonisolatedRefresh(note) })) }
	}
	
	public func refresh() async throws {
		guard let updateClosure else { return }
		load(try await updateClosure())
		try saveToCache()
	}
	
	public nonisolated func nonisolatedRefresh(_ note: Notification) {
		if note.name == .conveyDidSignOutNotification {
			clear()
		} else {
			Task {
				do {
					try await refresh()
				} catch {
					print("Error during refresh of \(String(describing: DownloadedItem.self)) cache: \(error)")
				}
			}
		}
	}

	var cacheLocation: URL? {
		guard let cacheName else { return nil }
		return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent(cacheName)
	}
	
	func saveToCache() throws {
		guard let cacheLocation else { return }
		let data = try JSONEncoder().encode(content)
		try data.write(to: cacheLocation, options: .atomic)
	}
	
	nonisolated func setup() { }
	func loadFromCache() {
		guard let cacheLocation else { return }
		do {
			let data = try Data(contentsOf: cacheLocation)
			let items = try JSONDecoder().decode(DownloadedItem.self, from: data)
			load(items)
		} catch {
			let ns = error as NSError
			if ns.domain == NSCocoaErrorDomain, ns.code == 260 { return }
			print("Failed to load \(DownloadedItem.self) from \(cacheLocation.path): \(error)")
		}
	}
}
