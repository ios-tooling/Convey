//
//  HTTPCookie.swift
//
//
//  Created by Ben Gottlieb on 8/14/23.
//

import Foundation

extension Array where Element == HTTPCookie {
	var cookieHeaderValue: String {
		map { cookie in
			"\(cookie.name)=\(cookie.value)"
		}
		.joined(separator: ";")
	}
}
