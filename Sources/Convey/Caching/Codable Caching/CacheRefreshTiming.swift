//
//  CacheRefreshTiming.swift
//  
//
//  Created by Ben Gottlieb on 5/3/24.
//

import Foundation

public struct CacheRefreshTiming: OptionSet, Sendable {
	public init(rawValue: Int) { self.rawValue = rawValue }
	public var rawValue: Int
	
	public static let atStartup = CacheRefreshTiming(rawValue: 0x0001 << 0)
	public static let atResume = CacheRefreshTiming(rawValue: 0x0001 << 1)
	public static let atSignIn = CacheRefreshTiming(rawValue: 0x0001 << 2)						// this is indicated by the host application posting conveyDidSignInNotification
	public static let atSignOut = CacheRefreshTiming(rawValue: 0x0001 << 3)						// this is indicated by the host application posting conveyDidSignOutNotification

	public static let always: CacheRefreshTiming = [.atStartup, .atResume, .atSignIn, .atSignOut]
}
