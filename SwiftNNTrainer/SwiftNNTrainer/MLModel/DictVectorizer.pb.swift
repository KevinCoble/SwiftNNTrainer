// DO NOT EDIT.
//
// Generated by the Swift generator plugin for the protocol buffer compiler.
// Source: DictVectorizer.proto
//
// For information on using the generated types, please see the documenation:
//   https://github.com/apple/swift-protobuf/

// Copyright (c) 2017, Apple Inc. All rights reserved.
//
// Use of this source code is governed by a BSD-3-clause license that can be
// found in LICENSE.txt or at https://opensource.org/licenses/BSD-3-Clause

import Foundation
import SwiftProtobuf

// If the compiler emits an error on this type, it is because this file
// was generated by a version of the `protoc` Swift plug-in that is
// incompatible with the version of SwiftProtobuf to which you are linking.
// Please ensure that your are building against the same version of the API
// that was used to generate this file.
fileprivate struct _GeneratedWithProtocGenSwiftVersion: SwiftProtobuf.ProtobufAPIVersionCheck {
  struct _2: SwiftProtobuf.ProtobufAPIVersion_2 {}
  typealias Version = _2
}

///*
/// Uses an index mapping to convert a dictionary to an array.
///
/// The output array will be equal in length to the index mapping vector parameter.
/// All keys in the input dictionary must be present in the index mapping vector.
///
/// For each item in the input dictionary, insert its value in the output array.
/// The position of the insertion is determined by the position of the item's key
/// in the index mapping. Any keys not present in the input dictionary, will be
/// zero in the output array.
///
/// For example: if the ``stringToIndex`` parameter is set to ``["a", "c", "b", "z"]``,
/// then an input of ``{"a": 4, "c": 8}`` will produce an output of ``[4, 8, 0, 0]``.
struct CoreML_Specification_DictVectorizer {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  var map: OneOf_Map? {
    get {return _storage._map}
    set {_uniqueStorage()._map = newValue}
  }

  //// String keys to indexes
  var stringToIndex: CoreML_Specification_StringVector {
    get {
      if case .stringToIndex(let v)? = _storage._map {return v}
      return CoreML_Specification_StringVector()
    }
    set {_uniqueStorage()._map = .stringToIndex(newValue)}
  }

  //// Int keys to indexes
  var int64ToIndex: CoreML_Specification_Int64Vector {
    get {
      if case .int64ToIndex(let v)? = _storage._map {return v}
      return CoreML_Specification_Int64Vector()
    }
    set {_uniqueStorage()._map = .int64ToIndex(newValue)}
  }

  var unknownFields = SwiftProtobuf.UnknownStorage()

  enum OneOf_Map: Equatable {
    //// String keys to indexes
    case stringToIndex(CoreML_Specification_StringVector)
    //// Int keys to indexes
    case int64ToIndex(CoreML_Specification_Int64Vector)

  #if !swift(>=4.1)
    static func ==(lhs: CoreML_Specification_DictVectorizer.OneOf_Map, rhs: CoreML_Specification_DictVectorizer.OneOf_Map) -> Bool {
      switch (lhs, rhs) {
      case (.stringToIndex(let l), .stringToIndex(let r)): return l == r
      case (.int64ToIndex(let l), .int64ToIndex(let r)): return l == r
      default: return false
      }
    }
  #endif
  }

  init() {}

  fileprivate var _storage = _StorageClass.defaultInstance
}

// MARK: - Code below here is support for the SwiftProtobuf runtime.

fileprivate let _protobuf_package = "CoreML.Specification"

extension CoreML_Specification_DictVectorizer: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = _protobuf_package + ".DictVectorizer"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "stringToIndex"),
    2: .same(proto: "int64ToIndex"),
  ]

  fileprivate class _StorageClass {
    var _map: CoreML_Specification_DictVectorizer.OneOf_Map?

    static let defaultInstance = _StorageClass()

    private init() {}

    init(copying source: _StorageClass) {
      _map = source._map
    }
  }

  fileprivate mutating func _uniqueStorage() -> _StorageClass {
    if !isKnownUniquelyReferenced(&_storage) {
      _storage = _StorageClass(copying: _storage)
    }
    return _storage
  }

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    _ = _uniqueStorage()
    try withExtendedLifetime(_storage) { (_storage: _StorageClass) in
      while let fieldNumber = try decoder.nextFieldNumber() {
        switch fieldNumber {
        case 1:
          var v: CoreML_Specification_StringVector?
          if let current = _storage._map {
            try decoder.handleConflictingOneOf()
            if case .stringToIndex(let m) = current {v = m}
          }
          try decoder.decodeSingularMessageField(value: &v)
          if let v = v {_storage._map = .stringToIndex(v)}
        case 2:
          var v: CoreML_Specification_Int64Vector?
          if let current = _storage._map {
            try decoder.handleConflictingOneOf()
            if case .int64ToIndex(let m) = current {v = m}
          }
          try decoder.decodeSingularMessageField(value: &v)
          if let v = v {_storage._map = .int64ToIndex(v)}
        default: break
        }
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    try withExtendedLifetime(_storage) { (_storage: _StorageClass) in
      switch _storage._map {
      case .stringToIndex(let v)?:
        try visitor.visitSingularMessageField(value: v, fieldNumber: 1)
      case .int64ToIndex(let v)?:
        try visitor.visitSingularMessageField(value: v, fieldNumber: 2)
      case nil: break
      }
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: CoreML_Specification_DictVectorizer, rhs: CoreML_Specification_DictVectorizer) -> Bool {
    if lhs._storage !== rhs._storage {
      let storagesAreEqual: Bool = withExtendedLifetime((lhs._storage, rhs._storage)) { (_args: (_StorageClass, _StorageClass)) in
        let _storage = _args.0
        let rhs_storage = _args.1
        if _storage._map != rhs_storage._map {return false}
        return true
      }
      if !storagesAreEqual {return false}
    }
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}
