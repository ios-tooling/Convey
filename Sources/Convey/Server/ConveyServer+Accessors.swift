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

public extension ConveyServer {
	nonisolated var pinnedServerKeys: [String: [String]] {
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
