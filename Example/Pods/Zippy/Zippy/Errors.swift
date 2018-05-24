//
//  Errors.swift
//  Zippy
//
//  Created by Clemens on 17/01/2017.
//  Copyright © 2017 Clemens Schulz. All rights reserved.
//

import Foundation

/**
File-related error
*/
public enum FileError: Error {
	/// Could not read file
	case readFailed

	/// Split ZIP file is missing segments
	case segmentMissing

	/// More split ZIP file segments than actually needed
	case tooManySegments

	/// File extension of split ZIP file does not conform to standard
	case invalidSegmentFileExtension

	/// File does not exist
	case doesNotExist

	/// Tried to read past end of file
	case endOfFileReached
}

/**
Zippy implementation-specific error
*/
public enum ZippyError: Error {
	/// Compression algorithm not implemented
	case unsupportedCompression

	/// ZIP file is using strong encryption, which requires special license agreement from PKWARE
	case unsupportedEncryption
}

public enum CompressionError: Error {
	/// Could not init (de)compression stream
	case initFailed

	/// Error during processing of (de)compression stream
	case processingError
}
