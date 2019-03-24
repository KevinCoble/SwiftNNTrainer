//
//  AtomicVariables.swift
//  SwiftNNTrainer
//
//  Created by Kevin Coble on 3/2/19.
//  Copyright © 2019 Kevin Coble. All rights reserved.
//

import Foundation

public final class AtomicInteger {
    
    private let lock = DispatchSemaphore(value: 1)
    private var _value: Int
    
    public init(_ initialValue: Int = 0) {
        _value = initialValue
    }
    
    public var value: Int {
        get {
            lock.wait()
            defer { lock.signal() }
            return _value
        }
        set {
            lock.wait()
            defer { lock.signal() }
            _value = newValue
        }
    }
    
    public func decrement() {
        lock.wait()
        defer { lock.signal() }
        _value -= 1
    }
    
    public func increment() {
        lock.wait()
        defer { lock.signal() }
        _value += 1
    }
    
    public func addValue(_ addition: Int) {
        lock.wait()
        defer { lock.signal() }
        _value += addition
    }
}

public final class AtomicBool {
    
    private let lock = DispatchSemaphore(value: 1)
    private var _state: Bool
    
    public init(_ initialState: Bool = false) {
        _state = initialState
    }
    
    public var state: Bool {
        get {
            lock.wait()
            defer { lock.signal() }
            return _state
        }
        set {
            lock.wait()
            defer { lock.signal() }
            _state = newValue
        }
    }
}
