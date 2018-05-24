//
//  ZipStructs.swift
//  Zippy
//
//  Created by Clemens on 14/01/2017.
//  Copyright © 2017 Clemens Schulz. All rights reserved.
//

import Foundation
import os

struct GeneralPurposeBitFlag: OptionSet {
	let rawValue: UInt16

	static let encryptedFile = GeneralPurposeBitFlag(rawValue: 1 << 0)
	static let compressionOption1 = GeneralPurposeBitFlag(rawValue: 1 << 1)
	static let compressionOption2 = GeneralPurposeBitFlag(rawValue: 1 << 2)
	static let dataDescriptor = GeneralPurposeBitFlag(rawValue: 1 << 3)
	static let enhancedDeflation = GeneralPurposeBitFlag(rawValue: 1 << 4)
	static let compressedPatchedData = GeneralPurposeBitFlag(rawValue: 1 << 5)
	static let strongEncryption = GeneralPurposeBitFlag(rawValue: 1 << 6)
	static let languageEncoding = GeneralPurposeBitFlag(rawValue: 1 << 11)
	static let maskHeaderValues = GeneralPurposeBitFlag(rawValue: 1 << 13)
}

enum CompressionMethod: UInt16 {
	case noCompression = 0
	case shrunk = 1
	case reducedWithCompressionFactor1 = 2
	case reducedWithCompressionFactor2 = 3
	case reducedWithCompressionFactor3 = 4
	case reducedWithCompressionFactor4 = 5
	case imploded = 6
	case deflated = 8
	case enhancedDeflated = 9
	case pkWareDCLImploded = 10
	case bzip2 = 12
	case lzma = 14
	case ibmTerse = 18
	case ibmLZ77z = 19
	case wavPackCompressedData = 97
	case ppmdVersionIRev1 = 98
}

struct Version: RawRepresentable {
	let rawValue: UInt16
}

struct MSDOSTime: RawRepresentable {
	let rawValue: UInt16

	var second: Int {
		return Int((rawValue & 0x1f) * 2) // Bit 0-4
	}

	var minute: Int {
		return Int(rawValue & 0x7e0 >> 5) // Bit 5-10
	}

	var hour: Int {
		return Int((rawValue & 0xf800) >> 11) // Bit 11-15
	}
}

struct MSDOSDate: RawRepresentable {
	let rawValue: UInt16

	var day: Int {
		return Int((rawValue & 0x1f) * 2) // Bit 0-4
	}

	var month: Int {
		return Int(rawValue & 0x1e0 >> 5) // Bit 5-8
	}

	var year: Int {
		return Int((rawValue & 0xfe00) >> 9) + 1980 // Bit 9-15
	}
}

protocol DataStruct {

	/**
	Reads data structure staring at `offset` on `disk`. If successful, `disk` and `offset` will be set to position of fist byte after structure.
	
	- Parameter data: Data of ZIP file
	- Parameter disk: Index of disk
	- Parameter offset: Offset on `disk` in bytes
	
	- Throws: Instance of `FileError` or `ZipError`. `disk` and `offset` will reflect position after error.
	*/
	init(data: SplitData, disk: inout Int, offset: inout Int) throws

}

extension DataStruct {

	init(data: SplitData, disk: Int, offset: Int) throws {
		var mutableDisk = disk
		var mutableOffset = offset
		try self.init(data: data, disk: &mutableDisk, offset: &mutableOffset)
	}

}

protocol ExtensibleDataField: DataStruct {

	/// Header ID
	static var headerID: UInt16 { get }

	/// Size of structure in bytes. Does not include header and data size field.
	var length: Int { get }

}

protocol ExtensibleDataReader {

	static func readExtensibleData(data: SplitData, disk: inout Int, offset: inout Int, length: Int) throws -> [ExtensibleDataField]
	
}

extension ExtensibleDataReader {

	static func readExtensibleData(data: SplitData, disk: inout Int, offset: inout Int, length: Int) throws -> [ExtensibleDataField] {
		if length == 0 {
			return []
		} else if length < 4 {
			throw ZipError.invalidExtraField
		}

		let possibleDataFieldTypes: [ExtensibleDataField.Type] = [Zip64ExtendedInformationExtraField.self]
		var extensibleDataFields: [ExtensibleDataField] = []

		do {
			var bytesRead = 0
			while bytesRead < length {
				var unknownHeaderID = true
				let headerID: UInt16 = try data.readLittleInteger(disk: disk, offset: offset)
				var fieldLength: Int = 0 // Field length including header and size bytes

				for fieldType in possibleDataFieldTypes {
					if fieldType.headerID == headerID {
						let dataField = try fieldType.init(data: data, disk: &disk, offset: &offset)
						extensibleDataFields.append(dataField)
						fieldLength = 4 + dataField.length
						unknownHeaderID = false
						break
					}
				}

				if unknownHeaderID {
					offset += 2 // Size of header ID
					let dataSize: UInt16 = try data.readLittleInteger(disk: &disk, offset: &offset)

					offset += Int(dataSize)
					fieldLength = 4 + Int(dataSize)

					let log = OSLog(subsystem: "Zippy", category: "ReadZIP")
					os_log("Unknown extensible data field with header ID 0x%04x and size of %d bytes", log: log, type: .debug, headerID, dataSize)
				}

				if bytesRead + fieldLength > length {
					throw ZipError.invalidExtraField
				}

				bytesRead += fieldLength
			}
		} catch FileError.endOfFileReached {
			throw ZipError.incomplete
		}

		return extensibleDataFields
	}

}


