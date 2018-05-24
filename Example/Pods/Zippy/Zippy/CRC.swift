//
//  CRC.swift
//  Zippy
//
//  Created by Clemens on 08.04.17.
//  Copyright © 2017 Clemens Schulz. All rights reserved.
//

import Foundation

protocol CRCInt: FixedWidthInteger, UnsignedInteger {}

extension UInt8: CRCInt {}
extension UInt16: CRCInt {}
extension UInt32: CRCInt {}
extension UInt64: CRCInt {}

struct CRC<T: CRCInt> {

	private let polynomial: T
	private var seed: T

	var value: T {
		return self.seed ^ ~0
	}

 	init(polynomial: T, seed: T = ~0) {
		self.seed = seed
		self.polynomial = polynomial
	}

	/**
	Lookup table containing CRC values for every possible byte.
	*/
	private lazy var lookupTable: [T] = {
		var lookupTable = [T](repeating: 0, count: 256)
		for i in 0..<256 {
			var crc = T(i)

			for _ in 0..<8 {
				if crc & 0x1 == 0x1 {
					// If first bit is 1, shift and XOR with polynomial
					crc = (crc >> 1) ^ self.polynomial
				} else {
					// If first bit is 0, just shift
					crc >>= 1
				}
			}

			lookupTable[i] = crc
		}
		return lookupTable
	}()

	/**
	Update CRC value with bytes.
	*/
	mutating func add(buffer: UnsafeBufferPointer<UInt8>) {
		var crc = self.seed
		for byte in buffer {
			// XOR byte with first byte of CRC
			let result = byte ^ UInt8((crc & 0xff))
			// Lookup the already computed CRC value and XOR with 1-byte-shifted CRC
			crc = (crc>>8) ^ self.lookupTable[Int(result)]
		}
		self.seed = crc
	}

	/**
	Update CRC value with bytes.
	*/
	mutating func add(bytes: UnsafePointer<UInt8>, count: Int) {
		let bufferPointer = UnsafeBufferPointer(start: bytes, count: count)
		self.add(buffer: bufferPointer)
	}

	/**
	Update CRC value with data.
	*/
	mutating func add(data: Data) {
		data.enumerateBytes { (block, _, _) in
			self.add(buffer: block)
		}
	}
}

extension CRC where T == UInt32 {
	init() {
		self.init(polynomial: 0xEDB88320)
	}

	/**
	Takes the two least significant bytes of the CRC-32 value.
	*/
	var crc16: UInt16 {
		return UInt16(self.value & 0xffff)
	}
}

typealias CRC32 = CRC<UInt32>
