//
//  GzipHeader.swift
//  Zippy
//
//  Created by Clemens on 09.04.17.
//  Copyright © 2017 Clemens Schulz. All rights reserved.
//

import Foundation

struct GzipHeader {

	static let signature: UInt16 = 0x8b1f

	var compressionMethod: GzipCompressionMethod?
	var flags: GzipFlag?
	var lastModificationTime: Date?
	var compressionFlags: GzipCompressionFlag?
	var operatingSystem: GzipOperatingSystem?

	var extraFieldsLength: UInt16?
	var extraFields: Data?

	var originalFileName: String?

	var headerChecksum: UInt16?

	/**
	Flag is set to `true` after the whole header has been parsed.
	*/
	private(set) var isComplete: Bool = false

	/**
	Flag is set to `false` if checksum in header doesn't match computed checksum. It's `true` in all other cases, even
	if there is no checksum.
	*/
	private(set) var isHederChecksumValid: Bool = true

	private var bufferedReader: BufferedReader?


	private var checkpoint: Int

	init() {
		self.bufferedReader = BufferedReader(littleEndian: true)
		self.bufferedReader?.checksum = CRC32()
		self.checkpoint = 0
	}

	/**
	Parses header in gzip file data. If `bytes` contains the full header, `self.isComplete` will be set to `true` and
	the length of the header (in bytes) will be returned. If the header is not complete, the return value will be equal
	to `count` and `self.isComplete` will remain `false`.
	
	- Parameter bytes: Pointer to bytes buffer
	- Parameter count: Number of bytes in buffer
	
	- Throws: Instance of `GzipError`
	
	- Returns: Number of bytes belonging to header, even if incomplete.
	*/
	mutating func read(bytes: UnsafePointer<UInt8>, count: Int) throws -> Int {
		guard let bufferedReader = self.bufferedReader else {
			return 0
		}

		let count = try bufferedReader.read(bytes: bytes, count: count) { (readingBuffer: UnsafeReadingBuffer) in
			var checkpoint = self.checkpoint
			do {
				if checkpoint < 1 {
					let signature: UInt16 = try readingBuffer.readInteger()
					if signature != GzipHeader.signature {
						throw GzipError.wrongSignature
					}
					checkpoint += 1
				}

				if checkpoint < 2 {
					self.compressionMethod = GzipCompressionMethod(rawValue: try readingBuffer.readInteger())
					if self.compressionMethod == nil {
						throw GzipError.invalidCompressionMethod
					}
					checkpoint += 1
				}

				if checkpoint < 3 {
					self.flags = GzipFlag(rawValue: try readingBuffer.readInteger())
					checkpoint += 1
				}

				if checkpoint < 4 {
					let timestamp: UInt32 = try readingBuffer.readInteger()
					self.lastModificationTime = Date(timeIntervalSince1970: TimeInterval(timestamp))
					checkpoint += 1
				}

				if checkpoint < 5 {
					self.compressionFlags = try readingBuffer.readInteger()
					checkpoint += 1
				}

				if checkpoint < 6 {
					self.operatingSystem = GzipOperatingSystem(rawValue: try readingBuffer.readInteger())
					if self.operatingSystem == nil {
						throw GzipError.invalidOperatingSystem
					}
					checkpoint += 1
				}

				if checkpoint < 7 {
					if self.flags != nil && self.flags!.contains(.containsExtraFields) {
						self.extraFieldsLength = try readingBuffer.readInteger()
					}
					checkpoint += 1
				}

				if checkpoint < 8 {
					if let extraFieldsLength = self.extraFieldsLength {
						self.extraFields = try readingBuffer.read(count: Int(extraFieldsLength))
					}
					checkpoint += 1
				}

				if checkpoint < 9 {
					if self.flags != nil && self.flags!.contains(.containsFilename) {
						let filenameData = try readingBuffer.read(until: 0)
						self.originalFileName = String(data: filenameData, encoding: .isoLatin1)
					}
					checkpoint += 1
				}

				if checkpoint < 10 {
					if self.flags != nil && self.flags!.contains(.containsHeaderChecksum) {
						let calculatedChecksum = bufferedReader.checksum!.crc16
						bufferedReader.checksum = nil
						self.headerChecksum = try readingBuffer.readInteger()

						if calculatedChecksum != self.headerChecksum {
							self.isHederChecksumValid = false
							throw GzipError.invalidHeaderChecksum
						}
					}
					checkpoint += 1
				}
			} catch BufferedReaderError.notEnoughData {
				self.checkpoint = checkpoint
				return
			}
			
			self.isComplete = true
		}

		return count
	}

}
