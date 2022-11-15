//
//  MD5.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 6/4/22.
//

import Foundation
import CryptoKit

@available(watchOS 6.0, iOS 13.0, macOS 10.15, *)
public extension String {
	var md5: String? {
		guard let data = data(using: .utf8) else { return nil }
		return Insecure.MD5.hash(data: data).map { String(format: "%02hhx", $0) }.joined()
	 }
}
