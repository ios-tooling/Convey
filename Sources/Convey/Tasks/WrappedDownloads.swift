//
//  ExtractedDownload.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 4/28/24.
//

import Foundation

public protocol CacheableContainer<ContainedContent>: CacheableContent {
	associatedtype ContainedContent: CacheableContent
	
	var wrapped: ContainedContent? { get }
}

public protocol WrappedDownloadArray<Element, ContainedContent>: CacheableContainer where ContainedContent == [Element] {
	associatedtype Element: Decodable & Sendable
}

public extension PayloadDownloadingTask where DownloadPayload: WrappedDownloadArray {
	func downloadArray() async throws -> [DownloadPayload.Element]? {
		try await downloadPayload().wrapped
	}
}

public extension PayloadDownloadingTask where DownloadPayload: CacheableContainer {
	func downloadItem() async throws -> DownloadPayload.ContainedContent? {
		try await downloadPayload().wrapped
	}
}


