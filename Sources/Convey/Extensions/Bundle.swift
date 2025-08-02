//
//  Bundle.swift
//  Convey
//
//  Created by Ben Gottlieb on 7/19/25.
//

import Foundation

extension Bundle {
	var version: String { return self.infoDictionary?["CFBundleShortVersionString"] as? String ?? "" }
	var buildNumber: String { return self.infoDictionary?["CFBundleVersion"] as? String ?? "" }
	var name: String { return self.infoDictionary?["CFBundleName"] as? String ?? "" }
	var copyright: String { return self.infoDictionary?["NSHumanReadableCopyright"] as? String ?? "" }
}
