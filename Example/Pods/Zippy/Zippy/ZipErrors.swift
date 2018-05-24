//
//  ZipErrors.swift
//  Zippy
//
//  Created by Clemens on 12.04.17.
//  Copyright © 2017 Clemens Schulz. All rights reserved.
//

import Foundation

/**
Error in ZIP file
*/
public enum ZipError: Error {
	/// End of central directory record missing
	case endOfCentralDirectoryRecordMissing

	/// ZIP file is incomplete
	case incomplete

	/// Unexpected bytes
	case unexpectedBytes

	/// Compression method is not in specs.
	case unknownCompressionMethod(method: UInt16)

	/// Offset or start disk of central directory is not in valid range
	case invalidCentralDirectoryOffset

	/// Length of central directory does not match actual length
	case invalidCentralDirectoryLength

	/// Number of entries in central directory does not match number in end record
	case invalidNumberOfCentralDirectoryEntries

	/// Redundant values are different
	case conflictingValues

	/// Unexpected signature
	case unexpectedSignature

	/// Multiple files with same name found
	case duplicateFileName

	/// Extensible data field contains invalid data
	case invalidExtraField

	/// Zip64 extended information field is missing
	case missingZip64ExtendedInformation
}
