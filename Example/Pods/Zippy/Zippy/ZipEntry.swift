//
//  ZipEntry.swift
//  Zippy
//
//  Created by Clemens on 14/01/2017.
//  Copyright © 2017 Clemens Schulz. All rights reserved.
//

import Foundation
import Compression

class FileEntry {

	var filename: String
	var comment: String?

	var lastModification: Date

	let checksum: UInt32
	let compressedSize: Int
	let uncompressedSize: Int

	var compressionMethod: CompressionMethod
	var compressionOption1: Bool
	var compressionOption2: Bool

	private let diskStartNumber: Int
	private let localHeaderOffset: Int
	// TODO: Use UInt64 instead of Int for size and offset

	init(header: CentralDirectoryFileHeader, encoding: String.Encoding) throws {
		// TODO: check version needed

		self.filename = String(data: header.filename, encoding: encoding) ?? ""
		self.comment = header.fileComment.count > 0 ? String(data: header.fileComment, encoding: encoding) : nil

		var dateComponents = DateComponents()
		dateComponents.calendar = Calendar(identifier: .gregorian)
		dateComponents.timeZone = TimeZone(abbreviation: "UTC")
		dateComponents.second = header.modificationTime.second
		dateComponents.minute = header.modificationTime.minute
		dateComponents.hour = header.modificationTime.hour
		dateComponents.day = header.modificationDate.day
		dateComponents.month = header.modificationDate.month
		dateComponents.year = header.modificationDate.year
		self.lastModification = dateComponents.date ?? Date(timeIntervalSince1970: 0.0)

		self.checksum = header.crc32checksum

		self.compressionMethod = header.compressionMethod
		self.compressionOption1 = header.flags.contains(.compressionOption1)
		self.compressionOption2 = header.flags.contains(.compressionOption2)

		// Extract 32-bit size and position values and check if 64-bit values are used
		var compressedSize = Int(header.compressedSize)
		var uncompressedSize = Int(header.uncompressedSize)
		var diskStartNumber = Int(header.diskNumberStart)
		var localHeaderOffset = Int(header.offsetOfLocalHeader)

		let zip64CompressedSize = (header.compressedSize == UInt32.max)
		let zip64UncompressedSize = (header.uncompressedSize == UInt32.max)
		let zip64DiskNumberStart = (header.diskNumberStart == UInt16.max)
		let zip64OffsetOfLocalHeader = (header.offsetOfLocalHeader == UInt32.max)

		if zip64CompressedSize || zip64UncompressedSize || zip64DiskNumberStart || zip64OffsetOfLocalHeader {
			var zip64ExtendedInfo: Zip64ExtendedInformationExtraField! = nil
			for oneExtraField in header.extraField {
				if let oneExtraField = oneExtraField as? Zip64ExtendedInformationExtraField {
					zip64ExtendedInfo = oneExtraField
				}
			}

			if zip64ExtendedInfo == nil {
				throw ZipError.missingZip64ExtendedInformation
			}

			if zip64CompressedSize {
				if zip64ExtendedInfo.compressedSize != nil {
					compressedSize = Int(zip64ExtendedInfo.compressedSize!)
				} else {
					throw ZipError.missingZip64ExtendedInformation
				}
			}

			if zip64UncompressedSize {
				if zip64ExtendedInfo.uncompressedSize != nil {
					uncompressedSize = Int(zip64ExtendedInfo.uncompressedSize!)
				} else {
					throw ZipError.missingZip64ExtendedInformation
				}
			}

			if zip64DiskNumberStart {
				if zip64ExtendedInfo.diskStartNumber != nil {
					diskStartNumber = Int(zip64ExtendedInfo.diskStartNumber!)
				} else {
					throw ZipError.missingZip64ExtendedInformation
				}
			}

			if zip64OffsetOfLocalHeader {
				if zip64ExtendedInfo.localHeaderOffset != nil {
					localHeaderOffset = Int(zip64ExtendedInfo.localHeaderOffset!)
				} else {
					throw ZipError.missingZip64ExtendedInformation
				}
			}
		}

		self.compressedSize = compressedSize
		self.uncompressedSize = uncompressedSize
		self.diskStartNumber = diskStartNumber
		self.localHeaderOffset = localHeaderOffset

		// TODO: check compression method
	}

	/**
	Returns uncompressed data.
	
	- Parameter data: Data of zip file
	
	- Throws: Instance of `ZipError`, `FileError` or `ZippyError`
	
	- Returns: Uncompressed data for file described by entry
	*/
	func extract(from data: SplitData) throws -> Data {
		var disk = self.diskStartNumber
		var offset = self.localHeaderOffset

		let localHeader = try LocalFileHeader(data: data, disk: &disk, offset: &offset)

		if localHeader.flags.contains(.encryptedFile) {
			if localHeader.flags.contains(.strongEncryption) {
				throw ZippyError.unsupportedEncryption
			}
			fatalError("not yet implemented")
			// TODO: read encryption header
		}

		let usesDataDescriptor = localHeader.flags.contains(.dataDescriptor)
		if usesDataDescriptor {
			// TODO: check if size + crc is set to zero
		} else {
			// TODO: check size before decompressing
			// TODO: is crc32 value for compressed or uncompressed data?
		}

		// TODO: check other header values?
		// TODO: zip64

		let compressedData = try data.subdata(disk: &disk, offset: &offset, length: self.compressedSize)

		if usesDataDescriptor {
			// TODO: read data descriptor and do same checks as before
		}

		switch compressionMethod {
		case .noCompression:
			return compressedData
		case .deflated:
			let data = compressedData.withUnsafeBytes { (body: UnsafePointer<UInt8>) -> Data in
				let algo = COMPRESSION_ZLIB
				let dst_buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: self.uncompressedSize)
				let dst_size = compression_decode_buffer(dst_buffer, uncompressedSize, body, self.compressedSize, nil, algo)
				let uncompressedData = Data(bytes: dst_buffer, count: dst_size)
				free(dst_buffer)
				return uncompressedData
			}
			// TODO: check for errors
			// TODO: move to Data extension
			return data
		default:
			throw ZippyError.unsupportedCompression
		}

		// TODO: check crc32 of uncompressed data
	}

}
