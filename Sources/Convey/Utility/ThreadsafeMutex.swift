//
//  ConveyThreadsafeMutex.swift
//  Convey
//
//  Created by Ben Gottlieb on 8/2/25.
//

import Foundation
import os.lock

final public class ConveyThreadsafeMutex<T>: @unchecked Sendable {
	private var _value: T
	private let _lock: UnsafeMutablePointer<os_unfair_lock_s>

	public init(_ v: T) {
		_value = v
		_lock = UnsafeMutablePointer<os_unfair_lock_s>.allocate(capacity: 1)
		_lock.initialize(to: os_unfair_lock_s())
	}

	deinit {
		_lock.deinitialize(count: 1)
		_lock.deallocate()
	}

	nonisolated public var value: T {
		get {
			os_unfair_lock_lock(_lock)
			let value = _value
			os_unfair_lock_unlock(_lock)
			return value
		}
		
		set {
			set(newValue)
		}
	}
	
	nonisolated public func set(_ value: T) {
		os_unfair_lock_lock(_lock)
		_value = value
		os_unfair_lock_unlock(_lock)
	}
	
	func perform(block: (inout T) -> Void) {
		os_unfair_lock_lock(_lock)
		block(&_value)
		os_unfair_lock_unlock(_lock)
	}
}
