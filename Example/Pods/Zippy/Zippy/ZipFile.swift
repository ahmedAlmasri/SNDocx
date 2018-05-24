//
//  ZipFile.swift
//  Zippy
//
//  Created by Clemens on 02/12/2016.
//  Copyright © 2016 Clemens Schulz. All rights reserved.
//

import Foundation

open class ZipFile: Sequence {

	private let fileData: SplitData
	private(set) var entries: [String:FileEntry]

	open var filenames: [String] {
		return Array(self.entries.keys)
	}

	open var comment: String?

	/**
	Initializes split ZIP file with segments at `segmentURLs`. URLs do not need to be ordered. Segment order will be
	inferred by file extension. (.z0, .z1, ...)

	- Parameter segmentURLs: URLs of ZIP file segments.

	- Throws: Error of type `FileError`, `ZipError`, or `ZippyError`.
	*/
	public convenience init(segmentURLs: [URL]) throws {
		let minSegment = 1
		let maxSegment = segmentURLs.count

		var segments = [(segment: Int, fileWrapper: FileWrapper)]()

		for url in segmentURLs {
			let segmentNumber: Int

			let ext = url.pathExtension
			if ext == "zip" {
				segmentNumber = maxSegment
			} else {
				if ext.count < 2 || ext.first != "z" {
					throw FileError.invalidSegmentFileExtension
				}

				let segment: Int! = Int(ext[ext.index(after: ext.startIndex)...])
				if segment < minSegment || segment >= maxSegment {
					throw FileError.invalidSegmentFileExtension
				}

				segmentNumber = segment
			}

			let fileWrapper = try FileWrapper(url: url, options: [])
			segments.append((segment: segmentNumber, fileWrapper: fileWrapper))
		}

		segments.sort { $0.segment < $1.segment }
		let fileWrappers: [FileWrapper] = segments.map { $0.fileWrapper }

		try self.init(fileWrappers: fileWrappers)
	}

	/**
	Initializes ZIP file at `url`.
	
	- Parameter url: URL to ZIP file.

	- Throws: Error of type `FileError`, `ZipError`, or `ZippyError`.
	*/
	public convenience init(url: URL) throws {
		let fileWrapper = try FileWrapper(url: url, options: [])
		try self.init(fileWrapper: fileWrapper)
		// TODO: find split ZIP segments automatically, if dictionary access possible
	}

	/**
	Initializes ZIP file. `fileWrapper` must be a regular-file file wrapper.
	
	- Parameter fileWrapper: Regular-file file wrapper containing ZIP data.

	- Throws: Error of type `FileError` or `ZipError`.
	*/
	public convenience init(fileWrapper: FileWrapper) throws {
		try self.init(fileWrappers: [fileWrapper])
	}

	/**
	Initializes split ZIP file. `fileWrappers` may only contain regular-file file wrappers and must be ordered by disk
	number. E.g.: disk 1 at index 0, disk 2 at index 1, …
	
	- Throws: Error of type `FileError` or `ZipError`.
	*/
	public init(fileWrappers: [FileWrapper]) throws {
		// Make sure all file wrappers wrap regular files
		for fileWrapper in fileWrappers {
			if !fileWrapper.isRegularFile {
				throw FileError.readFailed
			}
		}

		let fileData = SplitData(fileWrappers: fileWrappers)
		let lastDisk = fileData.numberOfDisks - 1

		// Find and read end of central directory record
		let endOfCentralDirRecOffset = try EndOfCentralDirectoryRecord.find(in: fileData)
		let endOfCentralDirRec = try EndOfCentralDirectoryRecord(data: fileData, offset: endOfCentralDirRecOffset)

		// Check if Zip64 locator exists and read it
		let zip64Locator: Zip64EndOfCentralDirectoryLocator?
		let zip64LocatorOffset = endOfCentralDirRecOffset - Zip64EndOfCentralDirectoryLocator.length
		if zip64LocatorOffset >= 0 {
			do {
				zip64Locator = try Zip64EndOfCentralDirectoryLocator(data: fileData, offset: zip64LocatorOffset)
			} catch ZipError.unexpectedSignature {
				zip64Locator = nil
			}
		} else {
			zip64Locator = nil
		}

		// Get position and size of central directory from end record or zip64 end record
		var centralDirectoryDisk: Int
		var centralDirectoryOffset: Int
		let centralDirectorySize: Int
		let centralDirectoryNumberOfEntries: Int
		let centralDirecotryExpectedEndOffsetOnLastDisk: Int

		if let zip64Locator = zip64Locator {
			// File is in Zip64 format.

			// Check if all disks are present
			let numberOfSegments = Int(zip64Locator.totalNumberOfDisks)
			if fileWrappers.count < numberOfSegments {
				throw FileError.segmentMissing
			} else if fileWrappers.count > numberOfSegments {
				throw FileError.tooManySegments
			}

			// Read zip64 end of central directory record
			var disk = Int(zip64Locator.zip64EndRecordStartDiskNumber)
			var offset = Int(zip64Locator.zip64EndRecordRelativeOffset)
			let zip64EndRecord = try Zip64EndOfCentralDirectoryRecord(data: fileData, disk: &disk, offset: &offset)
			if disk != lastDisk || offset != zip64LocatorOffset {
				// There are unused bytes between zip64 record and locator
				throw ZipError.unexpectedBytes
			}

			// Check if all disks are present (again)
			if numberOfSegments != Int(endOfCentralDirRec.diskNumber) + 1 {
				throw ZipError.conflictingValues
			}

			// Get values from record
			centralDirectoryDisk = Int(zip64EndRecord.centralDirectoryStartDiskNumber)
			centralDirectoryOffset = Int(zip64EndRecord.centralDirectoryOffset)
			centralDirectorySize = Int(zip64EndRecord.centralDirectorySize)
			centralDirectoryNumberOfEntries = Int(zip64EndRecord.totalEntries)
			centralDirecotryExpectedEndOffsetOnLastDisk = Int(zip64Locator.zip64EndRecordRelativeOffset)

			// TODO: check zip64EndRecord.entriesOnDisk
			// TODO: check zip64EndRecord.versionNeeded

		} else {
			// File is not in Zip64 format

			// Check if all disks are present
			let numberOfSegments = Int(endOfCentralDirRec.diskNumber) + 1
			if fileWrappers.count < numberOfSegments {
				throw FileError.segmentMissing
			} else if fileWrappers.count > numberOfSegments {
				throw FileError.tooManySegments
			}

			// Get values from record
			centralDirectoryDisk = Int(endOfCentralDirRec.centralDirectoryStartDiskNumber)
			centralDirectoryOffset = Int(endOfCentralDirRec.centralDirectoryOffset)
			centralDirectorySize = Int(endOfCentralDirRec.centralDirectorySize)
			centralDirectoryNumberOfEntries = Int(endOfCentralDirRec.totalEntries)
			centralDirecotryExpectedEndOffsetOnLastDisk = endOfCentralDirRecOffset
			// TODO: check endOfCentralDirRec.entriesOnDisk
		}

		// Get encoding for filenames and comments
		let encoding: String.Encoding = .utf8 // TODO: get actual encoding

		// Get file comment
		if endOfCentralDirRec.fileComment.count > 0 {
			self.comment = String(data: endOfCentralDirRec.fileComment, encoding: encoding)
		}

		// Basic check of central directory offset and size
		if centralDirectoryDisk > lastDisk || (centralDirectoryDisk == lastDisk && centralDirectoryOffset > endOfCentralDirRecOffset) {
			throw ZipError.invalidCentralDirectoryOffset
		} else if centralDirectoryDisk == lastDisk && centralDirectoryOffset + centralDirectorySize > endOfCentralDirRecOffset {
			throw ZipError.invalidCentralDirectoryLength
		}

		// Read entries from central directory

		// TODO: read central directory
		// TODO: check expected number of entries

		var disk = centralDirectoryDisk
		var offset = centralDirectoryOffset

		var fileEntries: [String:FileEntry] = [:]
		var numberOfFileEntries = 0

		var bytesRead = 0
		while bytesRead < centralDirectorySize {
			let fileHeader = try CentralDirectoryFileHeader(data: fileData, disk: &disk, offset: &offset)
			let fileEntry = try FileEntry(header: fileHeader, encoding: encoding)

			if fileEntries[fileEntry.filename] != nil {
				throw ZipError.duplicateFileName
			}

			if !fileEntry.filename.hasPrefix("__MACOSX/") {
				// Skip resource forks
				// TODO: find better way to identify resource fork. Probably using extra field
				fileEntries[fileEntry.filename] = fileEntry
			}

			numberOfFileEntries += 1 // Only used for comparing to entry count in end record
			bytesRead += fileHeader.length
			assert(fileHeader.length > 0)
		}

		// Check if end record reached
		if disk != lastDisk || offset != centralDirecotryExpectedEndOffsetOnLastDisk {
			throw ZipError.invalidCentralDirectoryLength
		}

		if numberOfFileEntries != centralDirectoryNumberOfEntries {
			throw ZipError.invalidNumberOfCentralDirectoryEntries
		}

		// TODO: support encrypted ZIP files

		self.fileData = fileData
		self.entries = fileEntries
	}

	/**
	Returns uncompressed data of file with specific filename. May return `nil` if file does not exist or an error
	occurred. To get more detailed error reason, use `read(filename:)`.
	
	- Parameter filename: Name of file
	
	- Returns: Uncompressed data of file or `nil`
	*/
	open subscript(filename: String) -> Data? {
		return try? self.read(filename: filename)
	}

	open func makeIterator() -> IndexingIterator<[String]> {
		return self.filenames.makeIterator()
	}

	/**
	Returns uncompressed data of file with specific filename.
	
	- Parameter filename: Name of file
	
	- Throws: `FileError.doesNotExist` if file does not exist or other errors of type `FileError`, `ZipError`, or
	`ZippyError`
	
	- Returns: Uncompressed data
	*/
	open func read(filename: String) throws -> Data {
		if let entry = self.entries[filename] {
			return try entry.extract(from: self.fileData)
		} else {
			throw FileError.doesNotExist
		}
	}

}
