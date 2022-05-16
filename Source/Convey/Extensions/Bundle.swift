//
//  Bundle.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 5/16/22.
//

import Foundation

extension Bundle {
   public var version: String { return self.infoDictionary?["CFBundleShortVersionString"] as? String ?? "" }
   public var buildNumber: String { return self.infoDictionary?["CFBundleVersion"] as? String ?? "" }
   public var name: String { return self.infoDictionary?["CFBundleName"] as? String ?? "" }
   public var copyright: String { return self.infoDictionary?["NSHumanReadableCopyright"] as? String ?? "" }
}
