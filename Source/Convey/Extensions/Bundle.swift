//
//  Bundle.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 5/16/22.
//

import Foundation

extension Bundle {
   var version: String { return self.infoDictionary?["CFBundleShortVersionString"] as? String ?? "" }
   var buildNumber: String { return self.infoDictionary?["CFBundleVersion"] as? String ?? "" }
   var name: String { return self.infoDictionary?["CFBundleName"] as? String ?? "" }
   var copyright: String { return self.infoDictionary?["NSHumanReadableCopyright"] as? String ?? "" }
}
