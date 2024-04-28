//
//  WrappedDownloadCache.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 4/28/24.
//

import Foundation
import Combine

public actor WrappedDownloadArrayCache<UpdateTask: PayloadDownloadingTask>: ObservableObject where UpdateTask.DownloadPayload: WrappedDownloadArray, UpdateTask.DownloadPayload.Element: Equatable {
	let _items: CurrentValueSubject<[UpdateTask.DownloadPayload.Element], Never> = .init(value: [])
	public nonisolated var items: [UpdateTask.DownloadPayload.Element] { _items.value }

	var updateTask: UpdateTask
	
	public func setUpdateTask(_ task: UpdateTask) {
		self.updateTask = task
	}
	
	init(updateTask: UpdateTask) {
		self.updateTask = updateTask
	}
	
	public func refresh() async throws {
		let newItems = try await updateTask.downloadArray()
		if _items.value != newItems {
			_items.send(newItems)
			Task { @MainActor in self.objectWillChange.send() }
		}
	}
}
