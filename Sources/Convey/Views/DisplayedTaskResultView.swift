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
	@State private var error: Error?
	@Binding var isFetching: Bool
	@State private var request: URLRequest?
	@EnvironmentObject var responses: ConsoleTaskResponseCache
	
	public init(task: any ConsoleDisplayableTask, isFetching: Binding<Bool>) {
		self.task = task
		_isFetching = isFetching
	}
	
	var response: ServerReturned? { responses[task] }
	
	public var body: some View {
		let result = response
		
		VStack {
			ScrollView {
				VStack(alignment: .leading) {
					if isFetching {
						HStack {
							Text("Downloading…")
								.opacity(0.66)
							
							ProgressView()
								.scaleEffect(0.5)
								.frame(height: 20)
						}
					}
					if let result {
						if let requestData = request?.descriptionData(maxUploadSize: task.server.maxLoggedUploadSize), let requestString = String(data: requestData, encoding: .utf8) {
							Text(requestString)
								.multilineTextAlignment(.leading)
								.font(.system(size: 14, weight: .regular, design: .monospaced))
						}
						if let header = String(data: task.loggingOutput(request: nil, data: nil, response: result.response, includeMarkers: false), encoding: .utf8) {
							Text(header)
								.multilineTextAlignment(.leading)
								.font(.system(size: 14, weight: .semibold, design: .monospaced))
						}
						resultBody
					} else if let error {
						Text(error.localizedDescription)
					}
				}
			}
		}
		.task {
			if result == nil { await fetchResult() }
		}
		.onReceive(responses.objectWillChange) { _ in
			if !isFetching, response == nil {
				Task { await fetchResult() }
			}
		}
	}
	
	@ViewBuilder var resultBody: some View {
		if let result = response {
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
	
	@MainActor func fetchResult() async {
		isFetching = true
		request = try? await task.buildRequest()
		do {
			print("Fetching \(task.displayString)")
			responses[task] = try await task.downloadDataWithResponse()
			print("Fetched task")
		} catch {
			responses.clearResults(for: task)
			self.error = error
		}
		isFetching = false
	}
}
