//
//  Zip64ExtendedInformationExtraField.swift
//  Zippy
//
//  Created by Clemens on 25/01/2017.
//  Copyright © 2017 Clemens Schulz. All rights reserved.
//

import Foundation

struct Zip64ExtendedInformationExtraField: ExtensibleDataField {

	static let headerID: UInt16 = 0x0001

	let length: Int
	let uncompressedSize: UInt64?
	let compressedSize: UInt64?
	let localHeaderOffset: UInt64?
	let diskStartNumber: UInt32?

	init(data: SplitData, disk: inout Int, offset: inout Int) throws {
		do {
			let headerID: UInt16 = try data.readLittleInteger(disk: &disk, offset: &offset)
			if headerID != Zip64ExtendedInformationExtraField.headerID {
				throw ZipError.unexpectedBytes
			}

			let dataSize: UInt16 = try data.readLittleInteger(disk: &disk, offset: &offset)
			if dataSize > 28 {
				throw ZipError.invalidExtraField
			}
			self.length = Int(dataSize)

			if dataSize >= 8 {
				let uncompressedSize: UInt64 = try data.readLittleInteger(disk: &disk, offset: &offset)
				self.uncompressedSize = uncompressedSize
			} else {
				self.uncompressedSize = nil
			}

			if dataSize >= 16 {
				let compressedSize: UInt64 = try data.readLittleInteger(disk: &disk, offset: &offset)
				self.compressedSize = compressedSize
			} else {
				self.compressedSize = nil
			}

			if dataSize >= 24 {
				let localHeaderOffset: UInt64 = try data.readLittleInteger(disk: &disk, offset: &offset)
				self.localHeaderOffset = localHeaderOffset
			} else {
				self.localHeaderOffset = nil
			}

			if dataSize >= 28 {
				let diskStartNumber: UInt32 = try data.readLittleInteger(disk: &disk, offset: &offset)
				self.diskStartNumber = diskStartNumber
			} else {
				self.diskStartNumber = nil
			}
		} catch FileError.endOfFileReached {
			throw ZipError.incomplete
		}
	}
	
}
