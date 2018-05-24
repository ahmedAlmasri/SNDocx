//
//  GzipConstants.swift
//  Zippy
//
//  Created by Clemens on 07.04.17.
//  Copyright © 2017 Clemens Schulz. All rights reserved.
//

import Foundation

enum GzipCompressionMethod: UInt8 {

	/// Deflate compression algorithm
	case deflate = 8

}

struct GzipFlag: OptionSet {

	let rawValue: UInt8

	/// `FTEXT` flag. Uncompressed data should be treated as text instead of binary data.
	static let dataIsText = GzipFlag(rawValue: 1 << 0)

	/// `FHCRC` flag. File contains a CRC-16 checksum for header.
	static let containsHeaderChecksum = GzipFlag(rawValue: 1 << 1)

	/// `FEXTRA` flag. File contains extra fields.
	static let containsExtraFields = GzipFlag(rawValue: 1 << 2)

	/// `FNAME` flag. File contains original file name string.
	static let containsFilename = GzipFlag(rawValue: 1 << 3)

	/// `FCOMMENT` flag. File contains file comment
	static let containsComment = GzipFlag(rawValue: 1 << 4)

}

typealias GzipCompressionFlag = UInt8

struct GzipDeflateCompressionFlag: OptionSet {

	let rawValue: UInt8

	/// Compressor used best compression
	static let usedBestCompression = GzipDeflateCompressionFlag(rawValue: 1 << 1)

	/// Compressor used fastest compression algorithm
	static let usedFastestCompression = GzipDeflateCompressionFlag(rawValue: 1 << 2)

}

enum GzipOperatingSystem: UInt8 {

	/// FAT filesystem (MS-DOS, OS/2, NT/Win32)
	case fatFilesystem = 0

	/// Amiga
	case amiga = 1

	/// VMS or OpenVMS
	case vms = 2

	/// UNIX
	case unix = 3

	/// VM/CMS
	case vmCMS = 4

	/// Atrai TOS
	case atariTOS = 5

	/// HPFS filesystem (OS/2, NT)
	case hpfsFilesystem = 6

	/// Macintosh
	case macintosh = 7

	/// Z-System
	case zSystem = 8

	/// CP/M
	case cpM = 9

	/// TOPS-20
	case tops20 = 10

	/// NTFS filesystem (NT)
	case ntfsFilesystem = 11

	/// QDOS
	case qdos = 12

	/// Acorn RISCOS
	case acornRISCOS = 13

	/// Unknown
	case unknown = 255

}
