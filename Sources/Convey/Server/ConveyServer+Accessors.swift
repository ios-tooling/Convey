//
//  ConveyServer+Accessors.swift
//  Convey
//
//  Created by Ben Gottlieb on 10/5/24.
//


#if canImport(UIKit)
	import UIKit
#endif

import Combine
import Foundation

public extension ConveyServer {
	struct PinnedServerKey: Codable, Hashable, Sendable {
		let key: String
		let validUntil: Date
	}
	
	func register(publicKey: String, for server: String, validUntil: Date = .distantFuture) {
		var keys = pinnedServerKeys[server, default: []]
		keys.append(.init(key: publicKey, validUntil: validUntil))
		pinnedServerKeys[server] = keys
	}

	nonisolated var pinnedServerKeys: [String: [PinnedServerKey]] {
		get { pinnedServerKeysSubject.value }
		set { pinnedServerKeysSubject.value = newValue }
	}
	
	nonisolated var configuration: Configuration {
		get { configurationSubject.value }
		set { configurationSubject.value = newValue }
	}
	
	#if os(iOS)
		nonisolated var application: UIApplication? {
			get { applicationSubject.value }
			set { applicationSubject.value = newValue }
		}
	#endif

}
