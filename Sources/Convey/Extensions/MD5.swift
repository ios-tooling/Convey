//
//  File.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/20/25.
//

import Foundation
import CryptoKit

@available(watchOS 6.0, iOS 13.0, macOS 10.15, *)
extension String {
	var md5: String? {
		guard let data = data(using: .utf8) else { return nil }
		return Insecure.MD5.hash(data: data).map { String(format: "%02hhx", $0) }.joined()
	 }
}
