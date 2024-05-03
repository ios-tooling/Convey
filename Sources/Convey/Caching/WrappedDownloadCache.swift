//
//  WrappedDownloadCache.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 4/28/24.
//

import Foundation
import Combine

@available(iOS 13, macOS 13, watchOS 8, visionOS 1, *)
public actor WrappedDownloadArrayCache<Downloader: PayloadDownloadingTask>: ObservableObject where Downloader.DownloadPayload: WrappedDownloadArray, Downloader.DownloadPayload.Element: Equatable {
	let _items: CurrentValueSubject<[Downloader.DownloadPayload.Element], Never> = .init([])
	public nonisolated var content: [Downloader.DownloadPayload.Element] { _items.value }

	var updateTask: Downloader
	var redirect: TaskRedirect?
	
	init(updateTask: Downloader) {
		self.updateTask = updateTask
	}
	
	func setRedirect(_ redirect: TaskRedirect?) async throws {
		self.redirect = redirect
		try await refresh()
	}
	
	public func load<NewDownloader: PayloadDownloadingTask>(from task: NewDownloader) async throws where NewDownloader.DownloadPayload: WrappedDownloadArray, NewDownloader.DownloadPayload.Element == Downloader.DownloadPayload.Element {
		load(items: try await task.downloadArray())
	}
	
	public func load(items newItems: [Downloader.DownloadPayload.Element]) {
		if _items.value != newItems {
			_items.send(newItems)
			Task { @MainActor in self.objectWillChange.send() }
		}
	}
	
	public func refresh() async throws {
		let task = updateTask
			.redirects(redirect)
		
		load(items: try await task.downloadArray())
	}
}
