//
//  URL+ContentType.swift
//  
//
//  Created by Ben Gottlieb on 10/14/22.
//

import Foundation

public extension URL {
	var mimeContentType: String {
		switch pathExtension.lowercased() {
		case "txt", "text": return "application/text"
		case "rtf": return "application/rtf"
		case "jpg", "jpeg": return "image/jpeg"
		case "png": return "image/png"
		case "gif": return "image/gif"
		case "pdf": return "application/pdf"
		case "pages": return "application/vnd.apple.pages"
		case "docx": return "vnd.openxmlformats-officedocument.wordprocessingml.document"
		case "doc": return "application/msword"
		default: return "application/octet-stream"
		}
	}
}
