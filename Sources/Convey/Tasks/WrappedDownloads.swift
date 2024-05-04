//
//  ExtractedDownload.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 4/28/24.
//

import Foundation

public protocol WrappedDownloadItem<WrappedItem>: CacheableContent {
	associatedtype WrappedItem: Decodable & Sendable
	
	static var wrappedKeypath: KeyPath<Self, WrappedItem?> { get }
	
	var wrapped: WrappedItem? { get }
}

public extension WrappedDownloadItem {
	var wrapped: WrappedItem? { self[keyPath: Self.wrappedKeypath] }
}

public protocol WrappedDownloadArray<Element, WrappedItem>: WrappedDownloadItem where WrappedItem == [Element], Element: Decodable {
	associatedtype Element: Decodable & Sendable
}

public extension PayloadDownloadingTask where DownloadPayload: WrappedDownloadArray {
	func downloadArray() async throws -> [DownloadPayload.Element]? {
		try await downloadPayload().wrapped
	}
}

public extension PayloadDownloadingTask where DownloadPayload: WrappedDownloadItem {
	func downloadItem() async throws -> DownloadPayload.WrappedItem? {
		try await downloadPayload().wrapped
	}
}

