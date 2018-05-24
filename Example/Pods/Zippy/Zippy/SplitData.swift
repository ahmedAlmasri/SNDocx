//
//  SplitData.swift
//  Zippy
//
//  Created by Clemens on 20/01/2017.
//  Copyright © 2017 Clemens Schulz. All rights reserved.
//

import Foundation

// TODO: thread-safe ZipDataWrapper that only keeps 1 file in memory at the same time

/**
This class lets you read continuous data from multiple Data objects.
*/
class SplitData {

	private let fileWrappers: [FileWrapper]
	var numberOfDisks: Int {
		return self.fileWrappers.count
	}

	private var data: [Int:Data]

	init(fileWrappers: [FileWrapper]) {
		self.fileWrappers = fileWrappers
		self.data = [:]
	}

	/**
	Returns data object for specific disk
	
	- Parameter disk: Index of disk
	
	- Throws: Instance of `FileError`
	
	- Returns: Data for disk
	*/
	private func data(forDisk disk: Int) throws -> Data {
		if let data = self.data[disk] {
			return data
		} else if let data = self.fileWrappers[disk].regularFileContents {
			self.data[disk] = data
			return data
		} else {
			throw FileError.readFailed
		}
	}

	/**
	Checks if specified range is in available data range.
	
	- Parameter disk: Index of disk
	- Parameter offset: Offset on disk in bytes
	- Parameter length: Number of bytes
	
	- Throws: Instance of `FileError`

	- Returns: `true` if specified range does not exceed beginning or end of file
	*/
	func canRead(disk: Int, offset: Int, length: Int) throws -> Bool {
		if disk >= self.numberOfDisks {
			return false
		}

		let data = try self.data(forDisk: disk)
		if offset < data.startIndex || offset >= data.endIndex {
			return false
		}

		if offset + length > data.endIndex {
			let remainingLength = length - (data.count - offset)
			return try self.canRead(disk: disk + 1, offset: 0, length: remainingLength)
		} else {
			return true
		}
	}

	/**
	Returns size of specified disk in bytes.
	
	- Parameter disk: Index of disk
	
	- Throws: Instance of `FileError`

	- Returns: Disk size in bytes
	*/
	func size(ofDisk disk: Int) throws -> Int {
		return try self.data(forDisk: disk).count
	}

	/**
	Returns a new copy of the data in a specified range.

	- Parameter disk: In: Index of disk. Out: Disk index of first byte after last read byte
	- Parameter offset: In: Offset on disk in bytes. Out: Offset of first byte after last read byte
	- Parameter length: Number of bytes to copy
	
	- Throws: Instance of `FileError`
	
	- Returns: Data at specified range
	*/
	func subdata(disk: inout Int, offset: inout Int, length: Int) throws -> Data {
		let data = try self.data(forDisk: disk)

		let remainingLength = max(offset + length - data.endIndex, 0)

		var subdata = data.subdata(in: offset..<min(offset+length, data.endIndex))
		offset += length

		if remainingLength > 0 {
			disk += 1
			offset = 0

			let remainingSubdata = try self.subdata(disk: &disk, offset: &offset, length: remainingLength)
			subdata.append(remainingSubdata)
		}

		return subdata
	}

	/**
	Returns integer value at specified offset
	
	- Parameter disk: In: Index of disk. Out: Disk index of first byte after last read byte
	- Parameter offset: In: Offset on disk in bytes. Out: Offset of first byte after last read byte

	- Throws: Instance of `FileError`

	- Returns: Integer at specified offset
	*/
	func readInteger<T: SwappableInteger>(disk: inout Int, offset: inout Int) throws -> T {
		let valueSize: Int = MemoryLayout<T>.size
		let subdata = try self.subdata(disk: &disk, offset: &offset, length: valueSize)
		return subdata.withUnsafeBytes { return $0.pointee }
	}

	/**
	Returns integer value that is stored in little-endian byte order at specified offset.

	- Parameter disk: In: Index of disk. Out: Disk index of first byte after last read byte
	- Parameter offset: In: Offset on disk in bytes. Out: Offset of first byte after last read byte

	- Throws: Instance of `FileError`

	- Returns: Integer at specified offset
	*/
	func readLittleInteger<T: SwappableInteger>(disk: inout Int, offset: inout Int) throws -> T {
		let value: T = try self.readInteger(disk: &disk, offset: &offset)
		return T(littleEndian: value)
	}

	/**
	Returns integer value that is stored in little-endian byte order at specified offset without modifying offset.

	- Parameter disk: In: Index of disk. Out: Disk index of first byte after last read byte
	- Parameter offset: In: Offset on disk in bytes. Out: Offset of first byte after last read byte

	- Throws: Instance of `FileError`

	- Returns: Integer at specified offset
	*/
	func readLittleInteger<T: SwappableInteger>(disk: Int, offset: Int) throws -> T {
		var mutableDisk = disk
		var mutableOffset = offset
		return try self.readLittleInteger(disk: &mutableDisk, offset: &mutableOffset)
	}

}
