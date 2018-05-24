//
//  CentralDirectoryFileHeader.swift
//  Zippy
//
//  Created by Clemens on 16/01/2017.
//  Copyright © 2017 Clemens Schulz. All rights reserved.
//

import Foundation
import os

struct InternalFileAttribute: OptionSet {

	let rawValue: UInt16

	static let apparentlyASCIIOrTextFile = InternalFileAttribute(rawValue: 1 << 0)
	static let controlFieldRecordsPrecedeLogicalRecords = InternalFileAttribute(rawValue: 1 << 2)

}

struct CentralDirectoryFileHeader: DataStruct, ExtensibleDataReader {

	static let signature: UInt32 = 0x02014b50
	static let minLength: Int = 46
	static let maxLength: Int = CentralDirectoryFileHeader.minLength + 3 * Data.IndexDistance(UInt16.max)

	let version: Version
	let versionNeeded: Version
	let flags: GeneralPurposeBitFlag
	let compressionMethod: CompressionMethod
	let modificationTime: MSDOSTime
	let modificationDate: MSDOSDate
	let crc32checksum: UInt32
	let compressedSize: UInt32
	let uncompressedSize: UInt32
	let filenameLength: UInt16
	let extraFieldLength: UInt16
	let fileCommentLength: UInt16
	let diskNumberStart: UInt16
	let internalAttributes: InternalFileAttribute
	let externalAttributes: UInt32
	let offsetOfLocalHeader: UInt32
	let filename: Data
	let extraField: [ExtensibleDataField]
	let fileComment: Data

	init(data: SplitData, disk: inout Int, offset: inout Int) throws {
		do {
			let signature: UInt32 = try data.readLittleInteger(disk: &disk, offset: &offset)
			if signature != CentralDirectoryFileHeader.signature {
				throw ZipError.unexpectedSignature
			}

			self.version = Version(rawValue: try data.readLittleInteger(disk: &disk, offset: &offset))
			self.versionNeeded = Version(rawValue: try data.readLittleInteger(disk: &disk, offset: &offset))
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
			self.fileCommentLength = try data.readLittleInteger(disk: &disk, offset: &offset)
			self.diskNumberStart = try data.readLittleInteger(disk: &disk, offset: &offset)
			self.internalAttributes = InternalFileAttribute(rawValue: try data.readLittleInteger(disk: &disk, offset: &offset))
			self.externalAttributes = try data.readLittleInteger(disk: &disk, offset: &offset)
			self.offsetOfLocalHeader = try data.readLittleInteger(disk: &disk, offset: &offset)

			let headerLength = Int(self.filenameLength) + Int(self.extraFieldLength) + Int(self.fileCommentLength) + 46
			let maxRecommendedLength = 65535
			if headerLength > maxRecommendedLength {
				let log = OSLog(subsystem: "Zippy", category: "ReadZIP")
				os_log("File header in central directory is %d bytes long and exceeds recommended max. size of %d bytes.", log: log, type: .debug, headerLength, maxRecommendedLength)
			}

			self.filename = try data.subdata(disk: &disk, offset: &offset, length: Int(self.filenameLength))
			self.extraField = try CentralDirectoryFileHeader.readExtensibleData(data: data, disk: &disk, offset: &offset, length: Int(self.extraFieldLength))
			self.fileComment = try data.subdata(disk: &disk, offset: &offset, length: Int(self.fileCommentLength))

			// TODO: read values from extra data if field is 0xffffffff (zip64 files)
		} catch FileError.endOfFileReached {
			throw ZipError.incomplete
		}
	}

	/**
	Size of header in bytes.
	*/
	var length: Int {
		return CentralDirectoryFileHeader.minLength + Int(self.filenameLength) + Int(self.extraFieldLength) + Int(self.fileCommentLength)
	}
	
}
