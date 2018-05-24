//
//  SwappableInteger.swift
//  Zippy
//
//  Created by Clemens on 21/01/2017.
//  Copyright © 2017 Clemens Schulz. All rights reserved.
//

import Foundation

protocol SwappableInteger: BinaryInteger {
	init(bigEndian value: Self)
	init(littleEndian value: Self)
	init(integerLiteral value: Self)
	var bigEndian: Self { get }
	var littleEndian: Self { get }
	var byteSwapped: Self { get }
}

extension UInt16: SwappableInteger {}
extension UInt32: SwappableInteger {}
extension UInt64: SwappableInteger {}
extension Int16: SwappableInteger {}
extension Int32: SwappableInteger {}
extension Int64: SwappableInteger {}

extension UInt8: SwappableInteger {

	init(bigEndian value: UInt8) {
		self.init(value)
	}

	init(littleEndian value: UInt8) {
		self.init(value)
	}

	init(integerLiteral value: UInt8) {
		self.init(value)
	}

	var littleEndian: UInt8 {
		return self
	}

	var bigEndian: UInt8 {
		return self
	}

	var byteSwapped: UInt8 {
		return self
	}

}

extension Int8: SwappableInteger {

	init(bigEndian value: Int8) {
		self.init(value)
	}

	init(littleEndian value: Int8) {
		self.init(value)
	}

	init(integerLiteral value: Int8) {
		self.init(value)
	}

	var littleEndian: Int8 {
		return self
	}

	var bigEndian: Int8 {
		return self
	}

	var byteSwapped: Int8 {
		return self
	}
	
}
