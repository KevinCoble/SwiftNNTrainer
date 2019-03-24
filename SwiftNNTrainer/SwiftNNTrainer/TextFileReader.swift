//
//  TextFileReader.swift
//  SwiftNNTrainer
//
//  Created by Kevin Coble on 2/19/19.
//  Copyright © 2019 Kevin Coble. All rights reserved.
//

import Foundation

public class TextFileReader
{
    let fileHandle : FileHandle?
    var lineDelimiter : String
    let fileURL : URL
    var currentOffset : UInt64
    var chunkSize : Int
    var totalFileLength : UInt64 = 0
    
    public init?(inFileURL: URL)
    {
        
        lineDelimiter = "\n"
        fileURL = inFileURL
        currentOffset = 0
        chunkSize = 16
        
        do {
            fileHandle = try FileHandle(forReadingFrom: fileURL)
            if (fileHandle == nil) {
                return nil;
            }
            fileHandle!.seekToEndOfFile()
            totalFileLength = fileHandle!.offsetInFile
            //we don't need to seek back, since readLine will do that.
        }
        catch {
            return nil
        }
    }
    
    deinit
    {
        if (fileHandle != nil) {fileHandle!.closeFile()}
        currentOffset = 0
    }
    
    public func readLine() -> String?
    {
        if (fileHandle == nil) { return nil }
        if (currentOffset >= totalFileLength) { return nil }
        
        let newLineData = lineDelimiter.data(using: String.Encoding.utf8)
        if (newLineData == nil) { return nil }
        fileHandle!.seek(toFileOffset: currentOffset)
        var currentData = Data()
        var shouldReadMore = true
        
        while (shouldReadMore) {
            if (self.currentOffset >= self.totalFileLength) { break; }
            var chunk = fileHandle!.readData(ofLength: chunkSize)
            if let delimiterRange = chunk.range(of: newLineData!) {
                //  Include the length so we can include the delimiter in the string
                chunk.removeSubrange((delimiterRange.lowerBound + newLineData!.count)..<chunk.count)
                shouldReadMore = false
            }
            currentData.append(chunk)
            currentOffset += UInt64(chunk.count)
        }
        
        let line = String(data: currentData, encoding: .utf8)
        return line;
    }
    
    func getOffsetOfLineDelimiter(data : Data, delimiter : Data) -> Int?
    {
        return nil
    }
    
    public func readASCIILine() -> String?
    {
        if (fileHandle == nil) { return nil }
        if (currentOffset >= totalFileLength) { return nil }
        
        let newLineData = lineDelimiter.data(using: String.Encoding.ascii)
        if (newLineData == nil) { return nil }
        fileHandle!.seek(toFileOffset: currentOffset)
        var currentData = Data()
        var shouldReadMore = true
        
        while (shouldReadMore) {
            if (self.currentOffset >= self.totalFileLength) { break; }
            var chunk = fileHandle!.readData(ofLength: chunkSize)
            if let delimiterRange = chunk.range(of: newLineData!) {
                //  Include the length so we can include the delimiter in the string
                chunk.removeSubrange((delimiterRange.lowerBound + newLineData!.count)..<chunk.count)
                shouldReadMore = false
            }
            currentData.append(chunk)
            currentOffset += UInt64(chunk.count)
        }
        
        let line = String(data: currentData, encoding: .ascii)
        return line;
    }

    public func readTrimmedLine() -> String?
    {
        let line = readLine()
        if let string = line {
            return string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return line
    }
    
    public func enumerateLinesUsingBlock(closure: (String) -> Bool)
    {
        var bStop = false
        while (!bStop) {
            let line = readLine()
            if (line == nil) {return}
            bStop = closure(line!)
        }
    }
}
