//
//  WeakSet.swift
//  SimpleCameraController
//
//  Created by Giancarlo on 4/15/16.
//  Copyright © 2016 gdaniele. All rights reserved.
//

import Foundation

class WeakSet<ObjectType>: SequenceType {

  var count: Int {
    return weakStorage.count
  }

  private let weakStorage = NSHashTable.weakObjectsHashTable()

  func addObject(object: ObjectType) {
    guard object is AnyObject else {
      fatalError("Object (\(object)) should be subclass of AnyObject")
    }
    weakStorage.addObject(object as? AnyObject)
  }

  func removeObject(object: ObjectType) {
    guard object is AnyObject else {
      fatalError("Object (\(object)) should be subclass of AnyObject")
    }
    weakStorage.removeObject(object as? AnyObject)
  }

  func removeAllObjects() {
    weakStorage.removeAllObjects()
  }

  func containsObject(object: ObjectType) -> Bool {
    guard object is AnyObject else {
      fatalError("Object (\(object)) should be subclass of AnyObject")
    }
    return weakStorage.containsObject(object as? AnyObject)
  }

  func generate() -> AnyGenerator<ObjectType> {
    let enumerator = weakStorage.objectEnumerator()
    return AnyGenerator {
      guard let next = enumerator.nextObject() as? ObjectType? else {
        fatalError()
      }
      return next
    }
  }
}
