//
//  ServerTask+MIME.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 10/13/22.
//

import Foundation

public extension String {
	static var sampleMIMEBoundary: String { "----------" + UUID().uuidString }
}

fileprivate extension String {
	var mimeData: Data {
		data(using: .utf8) ?? Data()
	}
}

fileprivate extension Data {
	mutating func append(_ string: String) {
		append(string.mimeData)
	}
}

fileprivate let lineBreak = "\r\n"

extension MIMEUploadingTask {
	public var dataToUpload: Data? { mimeData(base64Encoded: false) }
	
	public func mimeData(base64Encoded: Bool) -> Data? {
		guard let fields = mimeFields else { return nil }
		let boundary = mimeBoundary
	//	let contentType = "application/json;charset=utf-8"
		
		var data = Data()
		data.append(mimeBoundary + lineBreak)
		
		zip(fields, fields.indices).forEach { field, index in
			var text = ""
			
			text += field.mimeString(base64Encoded: base64Encoded)
			
			data.append(text)
			
			if !base64Encoded, let fieldData = field.dataContent {
				data.append(fieldData)
			}
			if index != fields.indices.last { data.append(boundary + lineBreak) }
		}
		
		data.append(boundary + "--")
		return data
	}
}

public enum MIMEMessageComponent {
	case text(name: String, content: String)
	case file(name: String, contentType: String, url: URL)
	case image(name: String, image: PlatformImage, quality: Double)
	case fileData(name: String, contentType: String, data: Data, filename: String)

	func mimeString(base64Encoded: Bool) -> String {
		var result = ""
		
		result.append("Content-Disposition: \(disposition)\(lineBreak)")
		result.append("Content-Type: \(contentType)\(lineBreak)\(lineBreak)")
		if let text = textContent {
			result.append(text)
			result.append(lineBreak)
		} else if base64Encoded, let encodedData = dataContent?.base64EncodedString() {
			result.append("Content-Transfer-Encoding: base64\(lineBreak)\(lineBreak)")
			result.append(encodedData)
			result.append(lineBreak)
		}
		return result
	}
	
	var disposition: String {
		switch self {
		case .text(let name, _): return "form-data; name=\"\(name)\""
		case .file(let name, _, let url): return "attachment; filename=\"\(url.lastPathComponent)\"; name=\"\(name)\""
		case .fileData(let name, _, _, let filename): return "attachment; filename=\"\(filename)\"; name=\"\(name)\""
		case .image(let name, _, _): return "attachment; filename=\"\(name).jpeg\"; name=\"\(name)\""
		}
	}
	
	var dataContent: Data? {
		switch self {
		case .image(_, let image, let quality): return image.jpegData(compressionQuality: quality)
		case .file(_, _, let url): return try? Data(contentsOf: url)
		case .fileData(_, _, let data, _): return data
		default: return nil
		}
	}
	
	var textContent: String? {
		switch self {
		case .text(_, let content): return content
		default: return nil
		}
	}
	
	var contentType: String {
		var result = rawContentType
		switch self {
		case .text: result += "; charset=\"iso-8859-1\""
		default: break
		}
		return result
	}
	
	var rawContentType: String {
		switch self {
		case .text: return "text/plain"
		case .file(_, let contentType, _): return contentType
		case .fileData(_, let contentType, _, _): return contentType
		case .image: return "image/jpeg"
		}
	}
	
	var name: String {
		switch self {
		case .text(let name, _): return name
		case .file(let name, _, _): return name
		case .fileData(let name, _, _, _): return name
		case .image(let name, _, _): return name
		}
	}
}
