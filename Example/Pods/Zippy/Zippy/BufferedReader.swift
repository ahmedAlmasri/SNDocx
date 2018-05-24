//
//  BufferedReader.swift
//  Zippy
//
//  Created by Clemens on 11.04.17.
//  Copyright © 2017 Clemens Schulz. All rights reserved.
//

import Foundation

enum BufferedReaderError: Error {
	case notEnoughData
}

class UnsafeReadingBuffer {

	var start: UnsafePointer<UInt8>
	var count: Int

	let reader: BufferedReader

	init(start: UnsafePointer<UInt8>, count: Int, reader: BufferedReader) {
		self.start = start
		self.count = count
		self.reader = reader
	}

	private func readIntoBuffer() {
		let data = Data(bytes: self.start, count: self.count)
		if self.reader.bufferedData == nil {
			self.reader.bufferedData = data
		} else {
			self.reader.bufferedData?.append(data)
		}

		self.start = self.start.advanced(by: self.count)
		self.count = 0
	}

	func read<ResultType>(count: Int, body: (UnsafePointer<UInt8>) throws -> ResultType) throws -> ResultType {
		var bufferedDataSize = self.reader.bufferedData?.count ?? 0

		// Check if enough data is available. If not, add data to buffer for next call and throw error.
		if count > bufferedDataSize + self.count {
			self.readIntoBuffer()
			throw BufferedReaderError.notEnoughData
		}

		// Check if buffer contains data and if yes, make sure it contains enough to satisfy request
		if bufferedDataSize > 0 && bufferedDataSize < count {
			let missingBytesCount = count - bufferedDataSize
			self.reader.bufferedData!.append(self.start, count: missingBytesCount)

			bufferedDataSize += missingBytesCount
			self.start = self.start.advanced(by: missingBytesCount)
			self.count -= missingBytesCount
		}

		let result: ResultType
		if bufferedDataSize > 0 {
			// Read data from buffer
			result = try self.reader.bufferedData!.withUnsafeBytes({ (bytes: UnsafePointer<UInt8>) -> ResultType in
				self.reader.checksum?.add(bytes: bytes, count: count)

				return try body(bytes)
			})

			self.reader.bufferedData!.removeFirst(count)
			bufferedDataSize -= count
		} else {
			self.reader.checksum?.add(bytes: self.start, count: count)

			result = try body(self.start)

			self.start = self.start.advanced(by: count)
			self.count -= count
		}

		return result
	}

	func readInteger<T: SwappableInteger>() throws -> T {
		let valueSize: Int = MemoryLayout<T>.size
		let value = try self.read(count: valueSize) { (bytes: UnsafePointer<UInt8>) -> T in
			return bytes.withMemoryRebound(to: T.self, capacity: 1, { $0.pointee })
		}

		if self.reader.littleEndian {
			return T(littleEndian: value)
		} else {
			return T(bigEndian: value)
		}
	}

	func read(until marker: UInt8) throws -> Data {
		var index = self.reader.bufferedData?.index(of: marker)
		if index == nil {
			let buffer = UnsafeBufferPointer(start: self.start, count: self.count)
			index = buffer.index(of: marker)
			if index != nil {
				index = index! + (self.reader.bufferedData?.count ?? 0)
			}
		}

		if let index = index {
			let readCount = index + 1
			return try self.read(count: readCount, body: { (bytes: UnsafePointer<UInt8>) -> Data in
				return Data(bytes: bytes, count: readCount - 1)
			})
		} else {
			self.readIntoBuffer()
			throw BufferedReaderError.notEnoughData
		}
	}

	func read(count: Int) throws -> Data {
		return try self.read(count: count) { (bytes: UnsafePointer<UInt8>) -> Data in
			return Data(bytes: bytes, count: count)
		}
	}

}

class BufferedReader {

	var littleEndian: Bool = true
	var checksum: CRC32?

	fileprivate var bufferedData: Data?

	init(littleEndian: Bool) {
		self.littleEndian = littleEndian
	}

	/**
	- Returns: Number of bytes consumed.
	*/
	func read(bytes: UnsafePointer<UInt8>, count: Int, body: (UnsafeReadingBuffer) throws -> Void) rethrows -> Int {
		let buffer = UnsafeReadingBuffer(start: bytes, count: count, reader: self)
		try body(buffer)
		return count - buffer.count
	}
	
}
