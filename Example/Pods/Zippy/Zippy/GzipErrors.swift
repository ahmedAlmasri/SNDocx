//
//  GzipErrors.swift
//  Zippy
//
//  Created by Clemens on 08.04.17.
//  Copyright © 2017 Clemens Schulz. All rights reserved.
//

import Foundation

public enum GzipError: Error {

	/// Wrong file signature
	case wrongSignature

	/// Invalid compression method flag. Only deflate is allowed.
	case invalidCompressionMethod

	/// Invalid value for operating system byte in header
	case invalidOperatingSystem

	/// Invalid header checksum
	case invalidHeaderChecksum

	/// File footer is not valid
	case invalidFooter

	/// Invalid data checksum
	case invalidDataChecksum

	/// Invalid uncompressed file size
	case invalidUncompressedFileSize

}
