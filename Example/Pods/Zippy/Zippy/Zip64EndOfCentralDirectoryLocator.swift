//
//  Zip64EndOfCentralDirectoryLocator.swift
//  Zippy
//
//  Created by Clemens on 18/01/2017.
//  Copyright © 2017 Clemens Schulz. All rights reserved.
//

import Foundation

/*
Structure of the Zip64 end of central directory locator:

	| Description									| Size		| Value
----+-----------------------------------------------+-----------+------------
0	| Signature										| 4 bytes	| 0x07064b50
----+-----------------------------------------------+-----------+------------
4	| Number of disk with start of zip64 end of		| 4 bytes	|
	| central directory record						|			|
----+-----------------------------------------------+-----------+------------
8	| Relative offset of the zip64 end of			| 8 bytes	|
	| central directory record						|			|
----+-----------------------------------------------+-----------+------------
16	| Total number of disks							| 4 bytes	|

Structure must be located on last disk.

*/

struct Zip64EndOfCentralDirectoryLocator: DataStruct {

	static let signature: UInt32 = 0x07064b50
	static let length: Int = 20

	/// Number of disk containing start of zip64 end of	central directory record
	let zip64EndRecordStartDiskNumber: UInt32

	/// Offset of zip64 end of	central directory record relative to locator start index
	let zip64EndRecordRelativeOffset: UInt64

	/// Total number of disks
	let totalNumberOfDisks: UInt32

	init(data: SplitData, offset: Int) throws {
		var mutableOffset = offset
		try self.init(data: data, offset: &mutableOffset)
	}

	init(data: SplitData, offset: inout Int) throws {
		var lastDisk = data.numberOfDisks - 1
		try self.init(data: data, disk: &lastDisk, offset: &offset)
	}

	init(data: SplitData, disk: inout Int, offset: inout Int) throws {
		do {
			let signature: UInt32 = try data.readLittleInteger(disk: &disk, offset: &offset)
			if signature != Zip64EndOfCentralDirectoryLocator.signature {
				throw ZipError.unexpectedSignature
			}

			self.zip64EndRecordStartDiskNumber = try data.readLittleInteger(disk: &disk, offset: &offset)
			self.zip64EndRecordRelativeOffset = try data.readLittleInteger(disk: &disk, offset: &offset)
			self.totalNumberOfDisks = try data.readLittleInteger(disk: &disk, offset: &offset)
		} catch FileError.endOfFileReached {
			throw ZipError.incomplete
		}

	}
	
}
