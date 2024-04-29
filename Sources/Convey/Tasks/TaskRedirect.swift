//
//  TaskRedirect.swift
//
//
//  Created by Ben Gottlieb on 4/29/24.
//

import Foundation

public enum TaskRedirect: Sendable { case bundle(name: String, enabled: Bool = true), documents(name: String, enabled: Bool = true)
	var enabled: Bool {
		switch self {
		case let .bundle(name: _, enabled: enabled): enabled
		case let .documents(name: _, enabled: enabled): enabled
		}
	}
	
	var baseURL: URL? {
		switch self {
		case let .bundle(name: name, enabled: _): return Bundle.main.url(forResource: name, withExtension: nil)
		case let .documents(name: name, enabled: _):
			if #available(iOS 16.0, *) {
				return URL.documentsDirectory.appendingPathComponent(name)
			} else {
				print("TaskRedirect.documents requires iOS 16 or later")
				return nil
			}
		}
	}
	
	func cache(response: ServerResponse) {
		guard let dataURL = baseURL else { return }
		let responseURL = dataURL.deletingPathExtension().appendingPathExtension(".urlResponse")
		
		do {
			try response.data.write(to: dataURL)
			let responseData = try NSKeyedArchiver.archivedData(withRootObject: response.response, requiringSecureCoding: false)
			try responseData.write(to: responseURL)
		} catch {
			print("Failed to cache re-directed task \(self): \(error)")
		}
	}
	
	var cached: ServerResponse? {
		guard let dataURL = baseURL else { return nil }
		let responseURL = dataURL.deletingPathExtension().appendingPathExtension(".urlResponse")

		do {
			let data = try Data(contentsOf: dataURL)
			let response: HTTPURLResponse
			if let responseData = try? Data(contentsOf: responseURL), let decoded = try NSKeyedUnarchiver.unarchivedObject(ofClass: HTTPURLResponse.self, from: responseData) {
				response = decoded
			} else {
				response = .init(url: dataURL, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
			}
			return ServerResponse(response: response, data: data, fromCache: true, startedAt: Date())
		} catch {
			return nil
		}
	}
}

