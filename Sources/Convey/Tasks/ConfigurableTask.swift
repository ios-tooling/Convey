//
//  ConfigurableTask.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/25/25.
//

import Foundation

public extension DownloadingTask {
	func timeout(_ value: TimeInterval) -> Self {
		var task = self
		if task.configuration == nil { task.configuration = .default }
		task.configuration?.timeout = value
		return task
	}
	
	func headers(_ value: Headers) -> Self {
		var task = self
		if task.configuration == nil { task.configuration = .default }
		task.configuration?.headers = value
		return task
	}
	
	func cookies(_ value: [HTTPCookie]) -> Self {
		var task = self
		if task.configuration == nil { task.configuration = .default }
		task.configuration?.cookies = value
		return task
	}
	
	func localSourceURL(_ value: URL) -> Self {
		var task = self
		if task.configuration == nil { task.configuration = .default }
		task.configuration?.localSourceURL = value
		return task
	}
	
	func echoStyle(_ value: TaskEchoStyle) -> Self {
		var task = self
		if task.configuration == nil { task.configuration = .default }
		task.configuration?.echoStyle = value
		return task
	}
	
	func gzipped(_ value: Bool) -> Self {
		var task = self
		if task.configuration == nil { task.configuration = .default }
		task.configuration?.gzip = value
		return task
	}
	
	func queryParameters(_ value: any TaskQueryParameters) -> Self {
		var task = self
		if task.configuration == nil { task.configuration = .default }
		task.configuration?.queryParameters = value
		return task
	}
}
