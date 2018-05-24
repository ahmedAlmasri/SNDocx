//
//  EndOfCentralDirectoryRecord.swift
//  Zippy
//
//  Created by Clemens on 15/01/2017.
//  Copyright © 2017 Clemens Schulz. All rights reserved.
//

import Foundation

/*
Structure of the end of central directory (c.d.) record:

	| Description									| Size		| Value
----+-----------------------------------------------+-----------+------------
0	| Signature										| 4 bytes	| 0x06054b50
----+-----------------------------------------------+-----------+------------
4	| Number of current disk						| 2 bytes	|
----+-----------------------------------------------+-----------+------------
6	| Number of disk that contains start of c.d.	| 2 bytes	|
----+-----------------------------------------------+-----------+------------
8	| Entries in c.d. on current disk				| 2 bytes	|
----+-----------------------------------------------+-----------+------------
10	| Total entries in c.d.							| 2 bytes	|
----+-----------------------------------------------+-----------+------------
12	| c.d. size in bytes							| 4 bytes	|
----+-----------------------------------------------+-----------+------------
16	| Offset of start of central directory with		| 4 bytes	|
	| respect to the starting disk number			|			|
----+-----------------------------------------------+-----------+------------
20	| File comment length							| 2 bytes	|
----+-----------------------------------------------+-----------+------------
22	| File comment									| variable	|

Structure must be located on last disk.

*/

struct EndOfCentralDirectoryRecord: DataStruct {

	static let signature: UInt32 = 0x06054b50
	static let minLength: Int = 22
	static let maxLength: Int = EndOfCentralDirectoryRecord.minLength + Data.IndexDistance(UInt16.max)

	/// The number of this disk (containing the end of central directory record)
	let diskNumber: UInt16

	/// Number of disk containing start of central directory
	let centralDirectoryStartDiskNumber: UInt16

	/// Number of entries in central directory on current disk
	let entriesOnDisk: UInt16 // TODO: entries on start disk or last disk?

	/// Total number of entries in central directory
	let totalEntries: UInt16

	/// Size of central directory in bytes
	let centralDirectorySize: UInt32

	/// Offset of start of central directory on disk that it starts on
	let centralDirectoryOffset: UInt32

	/// Length of file comment
	let fileCommentLength: UInt16

	/// File comment
	let fileComment: Data

	init(data: SplitData, offset: Int) throws {
		var mutableOffset = offset
		try self.init(data: data, offset: &mutableOffset)
	}

	init(data: SplitData, offset: inout Int) throws {
		var lastDisk = data.numberOfDisks - 1
		try self.init(data: data, disk: &lastDisk, offset: &offset)
	}

	init(data: SplitData, disk: inout Int, offset: inout Int) throws {
		let diskSize = try data.size(ofDisk: disk)

		do {
			let signature: UInt32 = try data.readLittleInteger(disk: &disk, offset: &offset)
			if signature != EndOfCentralDirectoryRecord.signature {
				throw ZipError.unexpectedSignature
			}

			self.diskNumber = try data.readLittleInteger(disk: &disk, offset: &offset)
			self.centralDirectoryStartDiskNumber = try data.readLittleInteger(disk: &disk, offset: &offset)
			self.entriesOnDisk = try data.readLittleInteger(disk: &disk, offset: &offset)
			self.totalEntries = try data.readLittleInteger(disk: &disk, offset: &offset)
			self.centralDirectorySize = try data.readLittleInteger(disk: &disk, offset: &offset)
			self.centralDirectoryOffset = try data.readLittleInteger(disk: &disk, offset: &offset)
			self.fileCommentLength = try data.readLittleInteger(disk: &disk, offset: &offset)
			self.fileComment = try data.subdata(disk: &disk, offset: &offset, length: Int(self.fileCommentLength))
		} catch FileError.endOfFileReached {
			throw ZipError.incomplete
		}

		if offset != diskSize {
			throw ZipError.unexpectedBytes
		}
	}

	/**
	Search for end of central directory record at end of `data`
	
	- Parameter data: Contents of zip-file(s)
	
	- Throws: Error of type `ZipError` or `FileError`
	
	- Returns: Offset of end of central directory record on last disk
	*/
	static func find(in data: SplitData) throws -> Int {
		// Search for end of central directory record from end of file in reverse
		let lastDisk = data.numberOfDisks - 1
		let endIndex = try data.size(ofDisk: lastDisk)

		var i = endIndex - EndOfCentralDirectoryRecord.minLength
		let minOffset = Swift.min(0, endIndex - EndOfCentralDirectoryRecord.maxLength)

		var endRecordFound = false
		while i >= minOffset {
			let potentialSignature: UInt32 = try data.readLittleInteger(disk: lastDisk, offset: i)
			if potentialSignature == EndOfCentralDirectoryRecord.signature {
				endRecordFound = true
				break
			}
			i -= 1
		}

		guard endRecordFound else {
			throw ZipError.endOfCentralDirectoryRecordMissing
		}

		return i
	}

}
