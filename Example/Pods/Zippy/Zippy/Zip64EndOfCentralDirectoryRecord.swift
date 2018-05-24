//
//  Zip64EndOfCentralDirectoryRecord.swift
//  Zippy
//
//  Created by Clemens on 18/01/2017.
//  Copyright © 2017 Clemens Schulz. All rights reserved.
//

import Foundation

/*
Structure of the Zip64 end of central directory (c.d.) record:

	| Description									| Size		| Value
----+-----------------------------------------------+-----------+------------
0	| Signature										| 4 bytes	| 0x06064b50
----+-----------------------------------------------+-----------+------------
4	| Size of record without first 12 byte			| 8 bytes	|
----+-----------------------------------------------+-----------+------------
12	| Version made by								| 2 bytes	|
----+-----------------------------------------------+-----------+------------
14	| Version needed to extract						| 2 bytes	|
----+-----------------------------------------------+-----------+------------
16	| Number of current disk						| 4 bytes	|
----+-----------------------------------------------+-----------+------------
20	| Number of disk containing start of c.d.		| 4 bytes	|
----+-----------------------------------------------+-----------+------------
24	| Entries in c.d. on current disk				| 8 bytes	|
----+-----------------------------------------------+-----------+------------
32	| Total entries in c.d.							| 8 bytes	|
----+-----------------------------------------------+-----------+------------
40	| c.d. size in bytes							| 8 bytes	|
----+-----------------------------------------------+-----------+------------
48	| Offset of start of c.d. on disk				| 8 bytes	|
	| containing start								|			|
----+-----------------------------------------------+-----------+------------
56	| Zip64 extensible data sector					| variable	|

*/

struct Zip64EndOfCentralDirectoryRecord: DataStruct, ExtensibleDataReader {

	static let signature: UInt32 = 0x06064b50
	static let minLength: Int = 56

	/// Length of Zip64 end of central directory record. Does not include the signature and length field itself.
	let length: UInt64

	/// Version that create ZIP archive
	let versionMadeBy: Version

	/// Min. version that is required to read ZIP file
	let versionNeeded: Version

	/// The number of this disk (containing the end of central directory record)
	let diskNumber: UInt32

	/// Number of disk containing start of central directory
	let centralDirectoryStartDiskNumber: UInt32

	/// Number of entries in central directory on current disk
	let entriesOnDisk: UInt64

	/// Total number of entries in central directory
	let totalEntries: UInt64

	/// Size of central directory in bytes
	let centralDirectorySize: UInt64

	/// Offset of start of central directory on disk that it starts on
	let centralDirectoryOffset: UInt64

	/// Data from extensible data sector
	let extensibleData: [ExtensibleDataField]

	init(data: SplitData, disk: inout Int, offset: inout Int) throws {
		do {
			let signature: UInt32 = try data.readLittleInteger(disk: &disk, offset: &offset)
			if signature != Zip64EndOfCentralDirectoryRecord.signature {
				throw ZipError.unexpectedSignature
			}

			self.length = try data.readLittleInteger(disk: &disk, offset: &offset)
			self.versionMadeBy = Version(rawValue: try data.readLittleInteger(disk: &disk, offset: &offset))
			self.versionNeeded = Version(rawValue: try data.readLittleInteger(disk: &disk, offset: &offset))
			self.diskNumber = try data.readLittleInteger(disk: &disk, offset: &offset)
			self.centralDirectoryStartDiskNumber = try data.readLittleInteger(disk: &disk, offset: &offset)
			self.entriesOnDisk = try data.readLittleInteger(disk: &disk, offset: &offset)
			self.totalEntries = try data.readLittleInteger(disk: &disk, offset: &offset)
			self.centralDirectorySize = try data.readLittleInteger(disk: &disk, offset: &offset)
			self.centralDirectoryOffset = try data.readLittleInteger(disk: &disk, offset: &offset)

			let extensibleDataLength = Int(self.length) - 44
			self.extensibleData = try Zip64EndOfCentralDirectoryRecord.readExtensibleData(data: data, disk: &disk, offset: &offset, length: extensibleDataLength)
		} catch FileError.endOfFileReached {
			throw ZipError.incomplete
		}
	}
	
}
