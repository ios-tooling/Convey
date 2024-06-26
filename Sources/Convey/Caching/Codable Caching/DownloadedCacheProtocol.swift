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

public protocol DownloadedCacheProtocol<DownloadedItem>: Actor, ObservableObject {
	associatedtype DownloadedItem: CacheableContent
	typealias UpdateClosure = (() async throws -> DownloadedItem?)

	func load(_ new: DownloadedItem?)
	func refresh(closure: (@Sendable () async throws -> DownloadedItem?)?) async throws

	nonisolated func clear()
	nonisolated func setup()
	
	nonisolated var content: DownloadedItem? { get }
	var cacheName: String { get }
	var redirect: TaskRedirect? { get set }
	var fileWatcher: FileWatcher? { get set }
	var notificationObservers: [Any] { get set }
	var updateClosure: UpdateClosure? { get set }
}

protocol DownloadedArrayCacheProtocol<DownloadedElement>: DownloadedCacheProtocol where DownloadedItem == [DownloadedElement] {
	associatedtype DownloadedElement: CacheableContent
	
	var items: [DownloadedElement] { get }
}

public extension DownloadedCacheProtocol {
	var cacheName: String { String(describing: DownloadedItem.self) + "_cache" }
	
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
			if refresh.contains(.atResume) {
				#if swift(>=6)
					self.refresh(on: UIApplication.didBecomeActiveNotification)
				#else
					await self.refresh(on: UIApplication.didBecomeActiveNotification)
				#endif
			}
			#endif

			if refresh.contains(.atSignIn) { self.refresh(on: .conveyDidSignInNotification) }
			if refresh.contains(.atSignOut) { self.refresh(on: .conveyDidSignOutNotification) }
		}
	}
	
	func addObserver(_ observer: Any) { notificationObservers.append(observer) }
	nonisolated func refresh(on name: Notification.Name) {
		Task { await addObserver(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main, using: { note in self.nonisolatedRefresh(note) })) }
	}
	
	func refresh(closure: (@Sendable () async throws -> DownloadedItem?)? = nil) async throws {
		guard let update = closure ?? updateClosure else { return }
		load(try await update())
		try saveToCache()
	}
	
	nonisolated func nonisolatedRefresh(_ note: Notification) {
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
		return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent(cacheName).deletingPathExtension().appendingPathExtension("json")
	}
	
	func saveToCache() throws {
		guard let cacheLocation else { return }
		if let content {
			let data = try JSONEncoder().encode(content)
			try FileManager.default.removeItemIfExists(at: cacheLocation)
			try data.write(to: cacheLocation, options: .atomic)
			if fileWatcher == nil, let redirect { setupRedirect(redirect) }
		} else {
			try FileManager.default.removeItemIfExists(at: cacheLocation)
			fileWatcher?.finish()
			fileWatcher = nil
		}
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
