//
//  ServerTask+MIME.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 10/13/22.
//

import Foundation

public extension String {
	static let sampleMIMEBoundary: String = { String.createBoundary() }()
}

extension String {
	fileprivate var mimeData: Data {
		data(using: .utf8) ?? Data()
	}
	
	public static func createBoundary() -> String {
		 var str = "----------bndry----------------"
		 let length = arc4random_uniform(11) + 30
		 let charSet = [Character]("-_1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")

		 for _ in 0..<length {
			  str.append(charSet[Int(arc4random_uniform(UInt32(charSet.count)))])
		 }
		 return str
	}
	
	public static func contentType(for boundary: String) -> String {
		"multipart/form-data; boundary=" + boundary
	}
}

fileprivate extension Data {
	mutating func append(_ string: String) {
		append(string.mimeData)
	}
}

fileprivate let lineBreak = "\r\n"

extension MIMEUploadingTask {
	public var dataToUpload: Data? { mimeFields?.mimeData(boundary: mimeBoundary, base64Encoded: base64EncodeBody) }
	public var contentType: String? { String.contentType(for: mimeBoundary) }

}

public extension [MIMEMessageComponent] {
	func mimeData(boundary mimeBoundary: String, base64Encoded: Bool = false) -> Data? {
		let boundary = "--" + mimeBoundary
		var data = Data()
		data.append(boundary + lineBreak)
		
		zip(self, self.indices).forEach { field, index in
			var text = ""
			
			text += field.mimeString(base64Encoded: base64Encoded)
			
			data.append(text)
			
			if !base64Encoded, let fieldData = field.dataContent {
				if field.isFormData {
					data.append("\(lineBreak)\(lineBreak)")
				}
				data.append(lineBreak)
				data.append(fieldData)
			}
			data.append(lineBreak)
			if index != self.indices.last { data.append(boundary + lineBreak) }
		}
		
		data.append(boundary + "--")
		return data
		
	}
}

public enum MIMEMessageComponent: Sendable {
	public enum FormDataFormat: String, Sendable { case form, json }
	
	case text(content: String)
	case file(contentType: String, url: URL)
	case data(contentType: String, data: Data)
	case image(name: String, image: PlatformImage, quality: Double)
	case formData(fields: [String: Sendable], format: FormDataFormat = FormDataFormat.form)
	case fileData(contentType: String, data: Data, filename: String)
	
	var isFormData: Bool {
		if case .formData = self { return true }
		return false
	}

	func mimeString(base64Encoded: Bool) -> String {
		var result = ""
		
		result.append("Content-Disposition: \(disposition)\(lineBreak)")
		result.append("Content-Type: \(contentType)\(lineBreak)")
		if let text = textContent {
			result.append(lineBreak)
			result.append(text)
		} else if base64Encoded, let encodedData = dataContent?.base64EncodedString() {
			result.append("Content-Transfer-Encoding: base64\(lineBreak)")
			result.append(lineBreak)
			result.append(encodedData)
		}
		return result
	}
	
	var disposition: String {
		switch self {
		case .formData: return "form-data; name=\"file\""
		case .data(_, _): return "form-data; name=\"file\""
		case .text(_): return "form-data; name=\"file\""
		case .file(_, let url): return "form-data; filename=\"\(url.lastPathComponent)\"; name=\"file\""
		case .fileData(_, _, let filename): return "form-data; filename=\"\(filename)\"; name=\"file\""
		case .image(let name, _, _): return "attachment; filename=\"\(name).jpeg\"; name=\"file\""
		}
	}
	
	var dataContent: Data? {
		switch self {
		case .image(_, let image, let quality): image.jpegData(compressionQuality: quality)
		case .file(_, let url): try? Data(contentsOf: url)
		case .fileData(_, let data, _): data
		case .data(_, let data): data
		case .formData(let fields, let format):
			switch format {
			case .json: (try? JSONSerialization.data(withJSONObject: fields))
			case .form:
				fields.reduce("") { r, d in r + "\(d.key)=\(d.value)&" }.data(using: .utf8)
			}
		default: nil
		}
	}
	
	var textContent: String? {
		switch self {
		case .text(let content): return content
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
		case .file(let contentType, _): return contentType
		case .fileData(let contentType, _, _): return contentType
		case .data(let contentType, _): return contentType
		case .image: return "image/jpeg"
		case .formData(_, let format):
			switch format {
			case .json: return "application/json"
			case .form: return "application/x-www-form-urlencoded"
			}
		}
	}
}
