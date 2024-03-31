//
//  SwiftUIView.swift
//  
//
//  Created by Ben Gottlieb on 6/19/22.
//

import SwiftUI

#if canImport(UIKit)

@available(watchOS, unavailable)
extension TaskManagerView {
	@MainActor struct TaskResultsDetails: View {
		let url: URL
		
		var string: String {
			guard let data = try? Data(contentsOf: url) else { return "No data found" }
			
			if
				let json = try? JSONSerialization.jsonObject(with: data),
				let reparsed = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]),
				let string = String(data: reparsed, encoding: .utf8)
			{
				return string
			}
			
			return String(data: data, encoding: .utf8) ?? "Un-parseable"
		}
		
		var body: some View {
			let view = ScrollView() {
				Text(string)
					.lineLimit(nil)
					.multilineTextAlignment(.leading)
					.font(font)
					.padding()
			}
			
			#if os(iOS)
				view.navigationBarItems(trailing: shareButton)
			#else
				view
			#endif
		}
		
		var shareButton: some View {
			Button(action: { }) {
				Image(systemName: "square.and.arrow.up")
			}
		}
		
		var font: Font {
			if #available(iOS 15.0, watchOS 8, *) {
				return Font.system(size: 12).monospaced()
			} else {
				return Font.body
			}
		}
	}
}

#endif
