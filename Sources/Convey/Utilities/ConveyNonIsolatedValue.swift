//
//  NonIsolatedWrapper.swift
//  Convey
//
//  Created by Ben Gottlieb on 10/4/24.
//

import Foundation
import SwiftUI

typealias os_unfair_lock_pointer = UnsafeMutablePointer<os_unfair_lock_s>

final class NonIsolatedWrapper<Value: Sendable>: Sendable {
	 nonisolated(unsafe) private var _value: Value
	 nonisolated(unsafe) private var lock: os_unfair_lock_pointer
	 
	 init(_ value: Value) {
		  _value = value
		  lock = UnsafeMutablePointer<os_unfair_lock_s>.allocate(capacity: 1)
		  lock.initialize(to: os_unfair_lock())

	 }

	 nonisolated(unsafe) var value: Value {
		  get {
				os_unfair_lock_lock(lock)
				let v = _value
				os_unfair_lock_unlock(lock)
				return v
		  }
		  
		  set {
				os_unfair_lock_lock(lock)
				_value = newValue
				os_unfair_lock_unlock(lock)
		  }
	 }
}

@MainActor @propertyWrapper public struct ConveyNonIsolatedValue<Value: Sendable>: DynamicProperty {
	 public init(wrappedValue: Value) {
		  _value = State(wrappedValue: NonIsolatedWrapper(wrappedValue))
	 }
	 
	 @State private var value: NonIsolatedWrapper<Value>
	 
	 public var wrappedValue: Value {
		  get {
				value.value
		  }
		  
		  set {
				value.value = newValue
		  }
	 }
}

