//
//  RecordedTask+JSON.swift
//  Convey
//
//  Created by Ben Gottlieb on 3/26/26.
//

import Foundation

@available(iOS 17, *)
extension RecordedTask {
	@MainActor func buildAttributedJSON(showingUpload: Bool) -> AttributedString {
		var result = AttributedString("")
		if let request = request {
			result += AttributedString("     ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯ REQUEST ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯ \n\n")

			result += request.attributedDescription
			if isGzipped { result += AttributedString("\n(gzipped)") }
			
			if showingUpload, let upload = httpBody?.prettyJSON {
				result += AttributedString(upload)
				result += AttributedString("\n")
			} else if let size = uploadSize, size > 0 {
				result += AttributedString("\nUpload size: \(size.bytesString)")
			}
		}
		
		if let error = error {
			var err = AttributedString("\nFailed: \(error)")
			err.foregroundColor = .red
			result += err
		}
		
		if let code = statusCode {
			result += AttributedString("\nStatus Code: \(code)")
		}
		if let response = data?.prettyJSON {
			result += AttributedString("\n\n     ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯ RESPONSE ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯ \n\n")
			result += AttributedString(response)
			result += AttributedString("\n")
		}
		
		return result

	}
	

}
