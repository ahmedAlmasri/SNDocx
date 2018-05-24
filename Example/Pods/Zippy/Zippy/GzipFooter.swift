//
//  GzipFooter.swift
//  Zippy
//
//  Created by Clemens on 10.04.17.
//  Copyright © 2017 Clemens Schulz. All rights reserved.
//

import Foundation

struct GzipFooter {

	static let length = 8

	/**
	CRC-32 checksum of uncompressed data.
	*/
	let checksum: UInt32

	/**
	Size in bytes of uncompressed data. For large files, `size modulo 2^32` will be used.
	*/
	let uncompressedDataSize: UInt32

	init(bytes: UnsafePointer<UInt8>, count: Int) throws {
		guard count == GzipFooter.length else {
			throw GzipError.invalidFooter
		}

		let reader = BufferedReader(littleEndian: true)
		let readingBuffer = UnsafeReadingBuffer(start: bytes, count: count, reader: reader)

		self.checksum = try readingBuffer.readInteger()
		self.uncompressedDataSize = try readingBuffer.readInteger()
	}

}
