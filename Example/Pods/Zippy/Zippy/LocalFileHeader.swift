//
//  LocalFileHeader.swift
//  Zippy
//
//  Created by Clemens on 14/01/2017.
//  Copyright © 2017 Clemens Schulz. All rights reserved.
//

import Foundation

struct LocalFileHeader: DataStruct {

	static let signature: UInt32 = 0x04034b50
	static let minLength: Int = 30

	let version: Version
	let flags: GeneralPurposeBitFlag
	let compressionMethod: CompressionMethod
	let modificationTime: MSDOSTime
	let modificationDate: MSDOSDate
	let crc32checksum: UInt32
	let compressedSize: UInt32
	let uncompressedSize: UInt32
	let filenameLength: UInt16
	let extraFieldLength: UInt16
	let filename: Data
	let extraField: Data

	init(data: SplitData, disk: inout Int, offset: inout Int) throws {
		do {
			let signature: UInt32 = try data.readLittleInteger(disk: &disk, offset: &offset)
			if signature != LocalFileHeader.signature {
				throw ZipError.unexpectedSignature
			}

			self.version = Version(rawValue: try data.readLittleInteger(disk: &disk, offset: &offset))
			self.flags = GeneralPurposeBitFlag(rawValue: try data.readLittleInteger(disk: &disk, offset: &offset))

			let compressionMethodRaw: UInt16 = try data.readLittleInteger(disk: &disk, offset: &offset)
			if let compressionMethod = CompressionMethod(rawValue: compressionMethodRaw) {
				self.compressionMethod = compressionMethod
			} else {
				throw ZipError.unknownCompressionMethod(method: compressionMethodRaw)
			}

			self.modificationTime = MSDOSTime(rawValue: try data.readLittleInteger(disk: &disk, offset: &offset))
			self.modificationDate = MSDOSDate(rawValue: try data.readLittleInteger(disk: &disk, offset: &offset))
			self.crc32checksum = try data.readLittleInteger(disk: &disk, offset: &offset)
			self.compressedSize = try data.readLittleInteger(disk: &disk, offset: &offset)
			self.uncompressedSize = try data.readLittleInteger(disk: &disk, offset: &offset)
			self.filenameLength = try data.readLittleInteger(disk: &disk, offset: &offset)
			self.extraFieldLength = try data.readLittleInteger(disk: &disk, offset: &offset)

			self.filename = try data.subdata(disk: &disk, offset: &offset, length: Int(self.filenameLength))
			self.extraField = try data.subdata(disk: &disk, offset: &offset, length: Int(self.extraFieldLength))
		} catch FileError.endOfFileReached {
			throw ZipError.incomplete
		}
	}
	
}
