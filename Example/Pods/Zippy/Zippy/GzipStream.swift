//
//  GzipStream.swift
//  Zippy
//
//  Created by Clemens on 10.04.17.
//  Copyright © 2017 Clemens Schulz. All rights reserved.
//

import Foundation
import Compression

public class GzipStream {

	var fileHeader: GzipHeader = GzipHeader()

	public var originalFileName: String? {
		return self.fileHeader.originalFileName
	}

	public var lastModification: Date? {
		return self.fileHeader.lastModificationTime
	}

	private let compressionStream: UnsafeMutablePointer<compression_stream>

	private var uncompressedDataChecksum = CRC32()
	private var uncompressedDataSize = 0

	public init() throws {
		self.compressionStream = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)

		let status = compression_stream_init(self.compressionStream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB)
		guard status == COMPRESSION_STATUS_OK else {
			throw CompressionError.initFailed
		}
	}

	deinit {
		compression_stream_destroy(self.compressionStream)
		self.compressionStream.deallocate(capacity: 1)
	}

	private var potentialFooterData: Data?

	public func process(data: Data, endOfFile: Bool = true) throws -> Data {
		var dataForProcessing: Data
		if var potentialFooterData = self.potentialFooterData {
			potentialFooterData.append(data)
			dataForProcessing = potentialFooterData
		} else {
			dataForProcessing = data
		}

		let potentialFooterDataRange: Range<Data.Index> = max(dataForProcessing.startIndex, dataForProcessing.endIndex - GzipFooter.length)..<dataForProcessing.endIndex
		self.potentialFooterData = dataForProcessing.subdata(in: potentialFooterDataRange)

		let uncompressedData = try dataForProcessing.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Data in
			var start = bytes
			var count = dataForProcessing.count

			if !self.fileHeader.isComplete {
				let headerLength = try self.fileHeader.read(bytes: start, count: count)
				assert(headerLength >= 0)

				start = start.advanced(by: headerLength)
				count -= headerLength

				if !self.fileHeader.isComplete {
					return Data()
				} else if self.fileHeader.compressionMethod != GzipCompressionMethod.deflate {
					throw ZippyError.unsupportedCompression
				}
			}

			let sourceBufferSize = max(0, count - GzipFooter.length)

			self.compressionStream.pointee.src_ptr = start
			self.compressionStream.pointee.src_size = sourceBufferSize

			// TODO: split source data into fixed sized blocks. blocks should be 1/5th of destination buffer size
			let destinationBufferSize = 64 * 1024
			let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: destinationBufferSize)

			var uncompressedData = Data()

			var status: compression_status
			repeat {
				self.compressionStream.pointee.dst_ptr = destinationBuffer
				self.compressionStream.pointee.dst_size = destinationBufferSize

				let flags: Int32 = endOfFile ? Int32(COMPRESSION_STREAM_FINALIZE.rawValue) : 0
				status = compression_stream_process(self.compressionStream, flags)
				if status == COMPRESSION_STATUS_ERROR {
					throw CompressionError.processingError
				}

				let destinationBytesCount = destinationBufferSize - self.compressionStream.pointee.dst_size
				uncompressedData.append(destinationBuffer, count: destinationBytesCount)

				self.uncompressedDataChecksum.add(bytes: destinationBuffer, count: destinationBytesCount)
				self.uncompressedDataSize += destinationBytesCount
			} while status == COMPRESSION_STATUS_OK && endOfFile

			destinationBuffer.deallocate(capacity: destinationBufferSize)

			return uncompressedData
		}

		if endOfFile {
			try self.potentialFooterData!.withUnsafeBytes({ (bytes: UnsafePointer<UInt8>) -> Void in
				let fileFooter = try GzipFooter(bytes: bytes, count: self.potentialFooterData!.count)

				if fileFooter.checksum != self.uncompressedDataChecksum.value {
					throw GzipError.invalidDataChecksum
				}

				if fileFooter.uncompressedDataSize != UInt32(self.uncompressedDataSize % Int(pow(Double(2), 32))) {
					throw GzipError.invalidUncompressedFileSize
				}
			})
		}

		return uncompressedData
	}

}
