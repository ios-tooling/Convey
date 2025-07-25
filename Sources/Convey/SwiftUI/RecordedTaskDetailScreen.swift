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
	
	var body: some View {
		VStack {
			ScrollView {
				TextEditor(text: .constant(json))
					.font(.system(size: 10))
					.lineLimit(nil)
					.fixedSize(horizontal: false, vertical: true)
					.multilineTextAlignment(.leading)
					.monospaced()
			}
			HStack {
				Button("Delete", role: .destructive) {
					task.modelContext?.delete(task)
					dismiss()
				}
			}
		}
		.navigationTitle(task.name)
		.onAppear {
			var result = ""
			if let submit = task.requestData?.prettyJSON {
				result = submit
			}
			
			if let response = task.data?.prettyJSON {
				if !result.isEmpty {
					result += "\n\n====== RESPONSE ==================================\n\n"
				}
				result += response
			}
			self.json = result
		}
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

