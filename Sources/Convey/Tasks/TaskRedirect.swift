//
//  TaskRedirect.swift
//
//
//  Created by Ben Gottlieb on 4/29/24.
//

import Foundation

public enum TaskRedirect: Sendable, Equatable { case bundle(name: String, enabled: Bool = true), documents(name: String, enabled: Bool = true)
	var enabled: Bool {
		switch self {
		case let .bundle(name: _, enabled: enabled): enabled
		case let .documents(name: _, enabled: enabled): enabled
		}
	}
	
	var dataURL: URL? {
		switch self {
		case let .bundle(name: name, enabled: _): return Bundle.main.url(forResource: name, withExtension: nil)
		case let .documents(name: name, enabled: _):
			if #available(iOS 16.0, macOS 13, watchOS 9, *) {
				return URL.documentsDirectory.appendingPathComponent(name)
			} else {
				print("TaskRedirect.documents requires iOS 16 or later")
				return nil
			}
		}
	}
	
	var responseURL: URL? {
		dataURL?.deletingPathExtension().appendingPathExtension("urlResponse")
	}
	
	func cache(response: ServerResponse) {
		guard let dataURL, let responseURL else { return }
		
		do {
			try response.data.write(to: dataURL)
			try response.response.write(to: responseURL)
			if #available(iOS 16.0, macOS 13.0, watchOS 9, *) {
				print("💾 Saved data to \(dataURL.path(percentEncoded: false))")
			} else {
				print("💾 Saved data to \(dataURL.path)")
			}
		} catch {
			print("Failed to cache re-directed task \(self): \(error)")
		}
	}
	
	var cached: ServerResponse? {
		guard let dataURL, let responseURL else { return nil }

		do {
			let data = try Data(contentsOf: dataURL)
			let response: HTTPURLResponse = (try? .load(from: responseURL)) ?? .init(url: dataURL, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
			
			if #available(iOS 16.0, macOS 13.0, watchOS 9, *) {
				print("💾 Restored data from \(dataURL.path(percentEncoded: false))")
			} else {
				print("💾 Restored data from \(dataURL.path)")
			}
			return ServerResponse(response: response, data: data, fromCache: true, startedAt: Date(), retryCount: nil)
		} catch {
			return nil
		}
	}
}

