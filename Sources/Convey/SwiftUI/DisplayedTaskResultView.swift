//
//  DisplayedTaskResultView.swift
//
//
//  Created by Ben Gottlieb on 1/6/24.
//

import SwiftUI

@available(iOS 16, macOS 13.0, *)
public struct DisplayedTaskResultView: View {
	let task: any ConsoleDisplayableTask
	@State private var result: ServerReturned?
	@State private var error: Error?
	
	public init(task: any ConsoleDisplayableTask, result: ServerReturned?) {
		self.task = task
		self.result = result
	}
	
	public var body: some View {
		VStack {
			ScrollView {
				if result != nil {
					resultBody
				} else if let error {
					Text(error.localizedDescription)
				}
			}
		}
		.task {
			if result == nil { await fetchResult() }
		}
	}
	
	@ViewBuilder var resultBody: some View {
		if let result {
			if let string = String(data: result.data, encoding: .utf8) {
				TextEditor(text: .constant(string))
					.multilineTextAlignment(.leading)
					.font(.system(size: 14, design: .monospaced))
					.scrollContentBackground(.hidden)
			} else {
				Text("\(result.data.count) bytes")
			}
		}
	}
	
	func fetchResult() async {
		do {
			print("Fetching \(task.displayString)")
			result = try await task.downloadDataWithResponse()
			print("Fetched task")
		} catch {
			self.error = error
		}
	}
}
