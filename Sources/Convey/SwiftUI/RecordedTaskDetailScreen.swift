//
//  RecordedTaskDetailScreen.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/25/25.
//

import SwiftUI

@available(iOS 17, macOS 14, watchOS 10, *)
struct RecordedTaskDetailScreen: View {
	let task: RecordedTask
	@Environment(\.dismiss) var dismiss
	@State var json = "no data"
	@State var attributedJSON = AttributedString("")
	@State var tempFileURL = URL.temporaryDirectory.appendingPathComponent("task.json")
	
	var body: some View {
		VStack {
			if #available(iOS 26.0, *) {
				TextEditor(text: .constant(attributedJSON))
					.disabled(true)
			} else {
				TextEditor(text: .constant(json))
			}
			
		}
			.font(.system(size: 10))
			.lineLimit(nil)
			.multilineTextAlignment(.leading)
			.monospaced()
			.safeAreaInset(edge: .bottom) {
				HStack {
					Button("Delete", role: .destructive) {
						task.modelContext?.delete(task)
						dismiss()
					}
					
					ShareLink(item: tempFileURL, subject: Text(task.name))
						.padding(.horizontal)
				}
			}
			.navigationTitle(task.name)
			.onAppear {
				self.attributedJSON = buildAttributedJSON()
				self.json = buildRawJSON()
				tempFileURL = URL.temporaryDirectory.appendingPathComponent(task.suggestedFilename)
				try? self.json.write(to: tempFileURL, atomically: true, encoding: .utf8)
			}
	}
	
	func buildAttributedJSON() -> AttributedString {
		var result = AttributedString("")
		if let request = task.request {
			result += AttributedString("     ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯ REQUEST ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯ \n\n")

			result += request.attributedDescription
			if task.isGzipped { result += AttributedString("\n(gzipped)") }
		}
		
		if let error = task.error {
			var err = AttributedString("\nFailed: \(error)")
			err.foregroundColor = .red
			result += err
		}
		
		if let response = task.data?.prettyJSON {
			result += AttributedString("\n\n     ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯ RESPONSE ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯ \n\n")
			result += AttributedString(response)
			result += AttributedString("\n")
		}
		
		return result

	}
	
	func buildRawJSON() -> String {
		var result = ""
		if let request = task.request {
			result += "     ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯ REQUEST ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯\n\n"
			result += request.description
			if task.isGzipped { result += "\n(gzipped)" }
		}
		
		if let error = task.error {
			result += "\nFailed: \(error)"
		}
		
		if let response = task.data?.prettyJSON {
			if !result.isEmpty {
				result += "\n\n     ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯ RESPONSE ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯\n\n"
			}
			result += response
			result += "\n"
		}
		
		return result
	}
}

extension Data {
	var prettyJSON: String? {
		var data = self
		if let expanded = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
			data = (try? JSONSerialization.data(withJSONObject: expanded, options: .prettyPrinted)) ?? data
		}
		return String(data: data, encoding: .utf8) ?? "unable to decode"
	}
}

