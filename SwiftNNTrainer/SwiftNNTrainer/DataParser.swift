//
//  DataParser.swift
//  SwiftNNTrainer
//
//  Created by Kevin Coble on 2/13/19.
//  Copyright © 2019 Kevin Coble. All rights reserved.
//

import Cocoa

enum DataChunkType : Int {
    case Unused = 1
    case Label = 2
    case LabelIndex = 3
    case Feature = 4
    case RedValue = 5
    case GreenValue = 6
    case BlueValue = 7
    case OutputValues = 8
    case Repeat = 100
    case SetDimension = 101
    
    var typeString : String
    {
        get {
            switch (self)
            {
            case .Unused:
                return "Unused"
            case .Label:
                return "Label"
            case .LabelIndex:
                return "Label #"
            case .Feature:
                return "Feature"
            case .RedValue:
                return "Red"
            case .GreenValue:
                return "Green"
            case .BlueValue:
                return "Blue"
            case .OutputValues:
                return "Output"
            case .Repeat:
                return "Repeat"
            case .SetDimension:
                return "Set Dim."
            }
        }
    }
}


enum DataFormatType : Int {
    case fInt8 = 1
    case fUInt8 = 2
    case fInt16 = 3
    case fUInt16 = 4
    case fInt32 = 5
    case fUInt32 = 6
    case fFloat = 7
    case fDouble = 8
    case fTextString = 9
    case fTextInt = 10
    case fTextFloat = 11
    case rDimension1 = 101
    case rDimension2 = 102
    case rDimension3 = 103
    case rDimension4 = 104
    case rSample = 105

    var typeString : String
    {
        get {
            switch (self)
            {
            case .fInt8:
                return "Int8"
            case .fUInt8:
                return "UInt8"
            case .fInt16:
                return "Int16"
            case .fUInt16:
                return "UInt16"
            case .fInt32:
                return "Int32"
            case .fUInt32:
                return "UInt32"
            case .fFloat:
                return "Float"
            case .fDouble:
                return "Double"
            case .fTextString:
                return "Text String"
            case .fTextInt:
                return "Text Integer"
            case .fTextFloat:
                return "Text Float"
            case .rDimension1:
                return "Dimension 1"
            case .rDimension2:
                return "Dimension 2"
            case .rDimension3:
                return "Dimension 3"
            case .rDimension4:
                return "Dimension 4"
            case .rSample:
                return "Sample"
           }
        }
    }

    var byteLength : Int
    {
        get {
            switch (self)
            {
            case .fInt8:
                return MemoryLayout<Int8>.size
            case .fUInt8:
                return MemoryLayout<Int8>.size
            case .fInt16:
                return MemoryLayout<Int8>.size
            case .fUInt16:
                return MemoryLayout<Int8>.size
            case .fInt32:
                return MemoryLayout<Int8>.size
            case .fUInt32:
                return MemoryLayout<Int8>.size
            case .fFloat:
                return MemoryLayout<Int8>.size
            case .fDouble:
                return MemoryLayout<Int8>.size
            case .fTextString, .fTextInt, .fTextFloat:
                return 1
            case .rDimension1, .rDimension2, .rDimension3, .rDimension4, .rSample:
                return 0
            }
        }
    }
}


enum PostReadProcessing : Int {
    case None = 1
    case Scale_0_1 = 2
    case Normalize_0_1 = 3
    case Normalize_M1_1 = 4
    case Normalize_All_0_1 = 5
    case Normalize_All_M1_1 = 6

    var typeString : String
    {
        get {
            switch (self)
            {
            case .None:
                return "None"
            case .Scale_0_1:
                return "Scale 0 to 1"
            case .Normalize_0_1:
                return "Norm. 0 to 1"
            case .Normalize_M1_1:
                return "Norm. -1 to 1"
            case .Normalize_All_0_1:
                return "Norm. All 0 to 1"
            case .Normalize_All_M1_1:
                return "Norm. All -1 to 1"
            }
        }
    }
}

class DataChunk : NSObject, NSCoding {
    let type : DataChunkType
    var length : Int
    let format : DataFormatType
    var repeatChunks : [DataChunk]?     //  If a repeating chunk, these are the chunks to repeat
    let postProcessing : PostReadProcessing
    
    var labels : [String]?
    
    var normalizationIndex : Int?
    
    init(type: DataChunkType, length: Int, format : DataFormatType, postProcessing : PostReadProcessing)
    {
        self.type = type
        self.length = length
        self.format = format
        self.repeatChunks = nil
        self.postProcessing = postProcessing
    }

    // MARK: - NSCoding
    required init?(coder aDecoder: NSCoder) {
        type = DataChunkType(rawValue: aDecoder.decodeInteger(forKey: "type"))!
        length = aDecoder.decodeInteger(forKey: "length")
        format = DataFormatType(rawValue: aDecoder.decodeInteger(forKey: "format"))!
        repeatChunks = aDecoder.decodeObject(forKey: "repeatChunks") as! [DataChunk]?
        postProcessing = PostReadProcessing(rawValue: aDecoder.decodeInteger(forKey: "postProcessing"))!

        super.init()
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(type.rawValue, forKey: "type")
        aCoder.encode(length, forKey: "length")
        aCoder.encode(format.rawValue, forKey: "format")
        aCoder.encode(repeatChunks, forKey: "repeatChunks")
        aCoder.encode(postProcessing.rawValue, forKey: "postProcessing")
    }
    
    // MARK: - Parsing
    func parseBinaryChunk(trainingData: TrainingData, inputFile : InputStream) -> Bool
    {
        //  Get the data for the types that can use it
        var data : [Float]?
        if (type != .Repeat && type != .SetDimension) {
            data = readBinaryData(inputFile : inputFile, postProcessing: postProcessing)
            if (data == nil) {
                trainingData.docData?.loadError = "Error reading binary data"
                return false
            }
        }
        
        //  Processing varies depending on the chunk type
        switch (type) {
        case .Unused:
            //  Throw away the unused data
            return true
        case .Label, .LabelIndex:
            //  Store the label for this data set
            if (!trainingData.appendOutputClass(Int(data![0]))) { return false }
        case .Feature:
            //  Store the feature values for the current input location
            if (!trainingData.appendInputData(data!, normalizationIndex: normalizationIndex)) { return false }
        case .RedValue:
            //  Store the red values for the current input location
            if (!trainingData.appendColorData(data!, channel: .red, normalizationIndex: normalizationIndex)) { return false }
        case .GreenValue:
            //  Store the green values for the current input location
            if (!trainingData.appendColorData(data!, channel: .green, normalizationIndex: normalizationIndex)) { return false }
        case .BlueValue:
            //  Store the blue values for the current input location
            if (!trainingData.appendColorData(data!, channel: .blue, normalizationIndex: normalizationIndex)) { return false }
        case .OutputValues:
            //  Store the output values for the current output location
            if (!trainingData.appendOutputData(data!, normalizationIndex: normalizationIndex)) { return false }
        case .Repeat:
            //  Set the stage for reading this dimension
            let dimension = format.rawValue - DataFormatType.rDimension1.rawValue
            //  Iterate
            for _ in 0..<length {
                //  If a sample iterator, increment up front so new sample can be created when needed
                if (format == .rSample) {
                    trainingData.incrementSample()
                }
                //  Process each chunk
                for chunk in repeatChunks! {
                    if (!chunk.parseBinaryChunk(trainingData: trainingData, inputFile : inputFile)) {
                        //  If a sample repeat, and and the current location is 0, delete last (empty) sample and return true - we are done
                        if (format == .rSample) {
                            let inputSum = trainingData.currentInputLocation.reduce(0, +)
                            let outputSum = trainingData.currentOutputLocation.reduce(0, +)
                            if (inputSum == 0 && outputSum == 0) {
                                if (trainingData.loadingTrainingData) {
                                    trainingData.trainingData.removeLast()
                                    trainingData.docData!.loadedTrainingSamples.decrement()
                                    trainingData.currentSample -= 1
                                }
                                else {
                                    trainingData.testingData.removeLast()
                                    trainingData.docData!.loadedTestingSamples.decrement()
                                    trainingData.currentSample -= 1
                                }
                                return true
                            }
                        }
                        return false
                    }
                }
                
                //  Increment the dimension
                if (format != .rSample) {
                    trainingData.currentInputLocation[dimension] += 1
                    trainingData.currentOutputLocation[dimension] += 1
                }
           }
        case .SetDimension:
            if (format == .rSample) {
                trainingData.currentSample = length
            }
            else {
                let dimension = format.rawValue - DataFormatType.rDimension1.rawValue
                trainingData.currentInputLocation[dimension] = length
                trainingData.currentOutputLocation[dimension] = length
            }
        }
        
        return true
    }
    
    func readBinaryData(inputFile : InputStream, postProcessing : PostReadProcessing) -> [Float]?
    {
        //  Read the data bytes
        let dataByteLength = format.byteLength
        let byteLength = dataByteLength * length
        var bytes = [UInt8](repeating: 0, count: byteLength)
        let numRead = inputFile.read(&bytes, maxLength: byteLength)
        if (numRead < byteLength) {
            return nil
        }
        
        //  Create the float array
        var floats = [Float](repeating: 0, count: length)

        //  Convert the bytes to the expected type, then to a float
        switch (format) {
        case .fInt8:
            let scaleFactor = 1.0 / Float(127)
            for index in 0..<length {
                var integer = Int(bytes[index])
                if (integer > Int8.max) { integer -= Int(UInt8.max) }
                let x : Int8 = Int8(integer)
                if (postProcessing == .Scale_0_1) {
                    floats[index] = Float(x) * scaleFactor
                }
                else {
                    floats[index] = Float(x)
                }
            }
        case .fUInt8:
            let scaleFactor = 1.0 / Float(255)
            for index in 0..<length {
                floats[index] = Float(bytes[index])
                if (postProcessing == .Scale_0_1) {
                    floats[index] = Float(bytes[index]) * scaleFactor
                }
                else {
                    floats[index] = Float(bytes[index])
                }
           }
        case .fInt16:
            let scaleFactor = 1.0 / Float(32767)
            for index in 0..<length {
                var intValue : Int16 = 0
                let data = NSData(bytes: bytes, length: byteLength)
                data.getBytes(&intValue, range: NSRange(location: index * dataByteLength, length: dataByteLength))
                if (postProcessing == .Scale_0_1) {
                    floats[index] = Float(intValue) * scaleFactor
                }
                else {
                    floats[index] = Float(intValue)
                }
           }
        case .fUInt16:
            let scaleFactor = 1.0 / Float(65535)
            for index in 0..<length {
                var uintValue : UInt16 = 0
                let data = NSData(bytes: bytes, length: byteLength)
                data.getBytes(&uintValue, range: NSRange(location: index * dataByteLength, length: dataByteLength))
                if (postProcessing == .Scale_0_1) {
                    floats[index] = Float(uintValue) * scaleFactor
                }
                else {
                    floats[index] = Float(uintValue)
                }
            }
        case .fInt32:
            for index in 0..<length {
                var intValue : Int32 = 0
                let data = NSData(bytes: bytes, length: byteLength)
                data.getBytes(&intValue, range: NSRange(location: index * dataByteLength, length: dataByteLength))
                floats[index] = Float(intValue)
                if (postProcessing == .Scale_0_1) { floats[index] /= Float(Int32.max) }
            }
        case .fUInt32:
            for index in 0..<length {
                var uintValue : UInt32 = 0
                let data = NSData(bytes: bytes, length: byteLength)
                data.getBytes(&uintValue, range: NSRange(location: index * dataByteLength, length: dataByteLength))
                floats[index] = Float(uintValue)
                if (postProcessing == .Scale_0_1) { floats[index] /= Float(UInt32.max) }
            }
        case .fFloat:
            for index in 0..<length {
                var uintValue : UInt32 = 0
                let data = NSData(bytes: bytes, length: byteLength)
                data.getBytes(&uintValue, range: NSRange(location: index * dataByteLength, length: dataByteLength))
                floats[index] = Float(bitPattern: uintValue)
            }
        case .fDouble:
            for index in 0..<length {
                var uintValue : UInt64 = 0
                let data = NSData(bytes: bytes, length: byteLength)
                data.getBytes(&uintValue, range: NSRange(location: index * dataByteLength, length: dataByteLength))
                floats[index] = Float(Double(bitPattern: uintValue))
            }
        case .fTextString:
            if let string = String(bytes: bytes, encoding: .utf8) {
                //  Convert the string to an index based on the known labels
                if let labels = labels {
                    for index in 0..<labels.count {
                        if(labels[index].caseInsensitiveCompare(string) == .orderedSame) {
                            return [Float(index)]
                        }
                    }
                }
            }
            return nil
        case .fTextInt:
            if let string = String(bytes: bytes, encoding: .utf8) {
                if let x = Int(string) {
                    return [Float(x)]
                }
            }
            return nil
        case .fTextFloat:
            if let string = String(bytes: bytes, encoding: .utf8) {
                if let x = Float(string) {
                    return [x]
                }
            }
            return nil        default:
            fatalError("invalid format type on data read")
        }
        
        return floats
    }
    
    func parseTextChunk(trainingData: TrainingData, components: [String], offset : Int) -> Int
    {
        //  Get the data for types that can use it
        var numUsed = 0
        var data : [Float]?
        if (type != .Repeat && type != .SetDimension) {
            data = [Float](repeating: 0.0, count: length)
            for i in 0..<length {
                let index = offset + i
                if (index >= components.count) {
                    trainingData.docData?.loadError = "Not enough components on line to match format"
                    return -1
                }
                if let value = getFloatData(component: components[index]) {
                    data![i] = value
                    numUsed += 1
                }
                else {
                    trainingData.docData?.loadError = "Invalid string value found at component index \(index)"
                    return -1
                }
            }
        }
        
        //  Processing varies depending on the chunk type
        switch (type) {
        case .Unused:
            //  Throw away the unused data
            return numUsed
        case .Label, .LabelIndex:
            //  Store the label for this data set
            if (!trainingData.appendOutputClass(Int(data![0]))) { return -1 }
        case .Feature:
            //  Store the feature values for the current input location
            if (!trainingData.appendInputData(data!, normalizationIndex: normalizationIndex)) { return -1 }
        case .RedValue:
            //  Store the red values for the current input location
            if (!trainingData.appendColorData(data!, channel: .red, normalizationIndex: normalizationIndex)) { return -1 }
        case .GreenValue:
            //  Store the green values for the current input location
            if (!trainingData.appendColorData(data!, channel: .green, normalizationIndex: normalizationIndex)) { return -1 }
        case .BlueValue:
            //  Store the blue values for the current input location
            if (!trainingData.appendColorData(data!, channel: .blue, normalizationIndex: normalizationIndex)) { return -1 }
        case .OutputValues:
            //  Store the output values for the current output location
            if (!trainingData.appendOutputData(data!, normalizationIndex: normalizationIndex)) { return -1 }
        case .Repeat:
            //  Set the stage for reading this dimension
            let dimension = format.rawValue - DataFormatType.rDimension1.rawValue
            if (dimension > 3) { break }        //  Skip sample iterators
            //  Iterate
            for _ in 0..<length {
                //  Process each chunk
                for chunk in repeatChunks! {
                    let usedComponents = chunk.parseTextChunk(trainingData: trainingData, components: components, offset : offset + numUsed)
                    if (usedComponents < 0) {
                        return -1
                    }
                    numUsed += usedComponents
                }
            }

            //  Increment the dimension
            if (format != .rSample) {
                trainingData.currentInputLocation[dimension] += 1
                trainingData.currentOutputLocation[dimension] += 1
            }
        case .SetDimension:
        if (format == .rSample) {
            trainingData.currentSample = length
        }
        else {
            let dimension = format.rawValue - DataFormatType.rDimension1.rawValue
            trainingData.currentInputLocation[dimension] = length
            trainingData.currentOutputLocation[dimension] = length
        }
    }

        return numUsed
    }
    
    func getFloatData(component: String) -> Float?
    {
        switch (format) {
        case .fTextString:
            //  Convert the string to an index based on the known labels
            if let labels = labels {
                for index in 0..<labels.count {
                    if(labels[index].caseInsensitiveCompare(component) == .orderedSame) {
                        return Float(index)
                    }
                }
            }
        case .fTextInt, .fTextFloat:
            return Float(component)
         default:
            return nil      //  Unsupported text type
        }
        
        return nil
    }

    func parseFixedWidthTextChunk(trainingData: TrainingData, string: String, index : String.Index) -> String.Index?
    {
        //  Get the data for types that can use it
        var data : Float = 0.0
        var startIndex = index
        var endIndex = startIndex
        if (type != .Repeat && type != .SetDimension) {
            endIndex = string.index(startIndex, offsetBy: length)
            let substring = string[startIndex..<endIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            if let value = Float(substring) {
                data = value
             }
            else {
                trainingData.docData?.loadError = "Invalid string value found at component index \(startIndex)"
                return nil
            }
        }
        
        //  Processing varies depending on the chunk type
        switch (type) {
        case .Unused:
            //  Throw away the unused data
            return endIndex
        case .Label, .LabelIndex:
            //  Store the label for this data set
            if (!trainingData.appendOutputClass(Int(data))) { return nil }
        case .Feature:
            //  Store the feature values for the current input location
            if (!trainingData.appendInputData([data], normalizationIndex: normalizationIndex)) { return nil }
        case .RedValue:
            //  Store the red values for the current input location
            if (!trainingData.appendColorData([data], channel: .red, normalizationIndex: normalizationIndex)) { return nil }
        case .GreenValue:
            //  Store the green values for the current input location
            if (!trainingData.appendColorData([data], channel: .green, normalizationIndex: normalizationIndex)) { return nil }
        case .BlueValue:
            //  Store the blue values for the current input location
            if (!trainingData.appendColorData([data], channel: .blue, normalizationIndex: normalizationIndex)) { return nil }
        case .OutputValues:
            //  Store the output values for the current output location
            if (!trainingData.appendOutputData([data], normalizationIndex: normalizationIndex)) { return nil }
        case .Repeat:
            //  Set the stage for reading this dimension
            let dimension = format.rawValue - DataFormatType.rDimension1.rawValue
            if (dimension > 3) { break }        //  Skip sample iterators
            //  Iterate
            for _ in 0..<length {
                //  Process each chunk
                for chunk in repeatChunks! {
                    let finalIndex = chunk.parseFixedWidthTextChunk(trainingData: trainingData, string: string, index : startIndex)
                    if (finalIndex == nil) {
                        return nil
                    }
                    startIndex = finalIndex!
                }
            }
            
            //  Increment the dimension
            if (format != .rSample) {
                trainingData.currentInputLocation[dimension] += 1
                trainingData.currentOutputLocation[dimension] += 1
            }
        case .SetDimension:
            if (format == .rSample) {
                trainingData.currentSample = length
            }
            else {
                let dimension = format.rawValue - DataFormatType.rDimension1.rawValue
                trainingData.currentInputLocation[dimension] = length
                trainingData.currentOutputLocation[dimension] = length
            }
        }
        
        return endIndex
    }
    
    //  MARK: NSCopying
    func copy(with zone: NSZone? = nil) -> Any {
        fatalError("copyWithZone not implemented")
    }
}


//  MARK: - DataParser

class DataParser : NSObject, NSCoding {
    var chunks : [DataChunk]
    var numSkipLines : Int
    var commentIndicators : [String]

    override init() {
        chunks = []
        numSkipLines = 0
        commentIndicators = []
        
        super.init()
    }
    
    func getNumDisplayChunks() -> Int
    {
        return getSubChunkCount(chunks)
    }
    func getSubChunkCount(_ array : [DataChunk]) -> Int {
        var numChunks = 0
        
        for chunk in array {
            numChunks += 1
            if (chunk.type == .Repeat) {
                numChunks += getSubChunkCount(chunk.repeatChunks!)
            }
        }
        
        return numChunks
    }
    
    func hasSampleRepeat() -> Bool
    {
        return hasSampleRepeatIn(chunks)
    }
    func hasSampleRepeatIn(_ array : [DataChunk]) -> Bool
    {
        for chunk in array {
            if (chunk.type == .Repeat) {
                if (chunk.format == .rSample)  { return true }
                let result = hasSampleRepeatIn(chunk.repeatChunks!)
                if (result) { return true }
            }
        }
        
        return false
    }
    
    func getDisplayLengthOfDataSample() -> Int
    {
        return getDisplayLengthIn(chunks)
    }
    func getDisplayLengthIn(_ array : [DataChunk]) -> Int
    {
        var total = 0;
        for chunk in array {
            if (chunk.type == .Repeat) {
                total += getDisplayLengthIn(chunk.repeatChunks!)
            }
            else if (chunk.type != .SetDimension) {
                total += chunk.length
            }
        }
        return total
    }
    
    func getChunkAtDisplayIndex(_ index : Int) -> (chunk: DataChunk, repeatLevel : Int)?
    {
        return getChunkFromArray(chunks, atIndex: index, startDispIndex: 0, startRepeat: 0)
    }
    func getChunkFromArray(_ array : [DataChunk], atIndex: Int, startDispIndex: Int, startRepeat: Int) -> (chunk: DataChunk, repeatLevel : Int)?
    {
        var dispIndex = startDispIndex
        
        for chunk in array {
            //  See if this is the chunk in question
            if (dispIndex == atIndex) {
                return (chunk: chunk, repeatLevel: startRepeat)
            }
            dispIndex += 1

            //  If a repeat chunk, recurse
            if (chunk.type == .Repeat) {
                if let repeatResult = getChunkFromArray(chunk.repeatChunks!, atIndex: atIndex, startDispIndex: dispIndex, startRepeat: startRepeat+1) {
                    return repeatResult
                }
                dispIndex += chunk.repeatChunks!.count
            }
        }
        
        return nil
    }
    
    func rangeCanRepeat(startIndex : Int, endIndex : Int) -> Bool {
        let result = subChunkCanRepeat(chunks, startIndex : startIndex, endIndex : endIndex, numChunksBefore: 0)
        return result.canRepeat
    }
    func subChunkCanRepeat(_ array : [DataChunk], startIndex : Int, endIndex : Int, numChunksBefore: Int) -> (numChunksAfterSet: Int, canRepeat: Bool)
    {
        var numChunks = numChunksBefore
        var startedInThisSet = false
        
        for chunk in array {
            if (numChunks >= startIndex) {
                startedInThisSet = true
            }
            
            if (chunk.type == .Repeat) {
                let result = subChunkCanRepeat(chunk.repeatChunks!, startIndex : startIndex, endIndex : endIndex, numChunksBefore: numChunks+1)
                numChunks = result.numChunksAfterSet
                //  If found repeatable in subchunk - pass it up
                if (result.canRepeat) { return (numChunksAfterSet: numChunks, canRepeat : true) }
            }
            else {
                numChunks += 1
            }
            if (numChunks == endIndex+1 && startedInThisSet) { return (numChunksAfterSet: numChunks, canRepeat : true) }     //  Started and ended in this set - repeatable
             if (numChunks > endIndex)  { return (numChunksAfterSet: numChunks, canRepeat : false) }       //  Past end, we are done
        }
        
        return (numChunksAfterSet: numChunks, canRepeat : false)
    }
    
    func activeRepeats(atDisplayIndex: Int) -> [Bool]
    {
        let startList = [Bool](repeating: false, count: 5)
        return activeRepeatsIn(chunks, atDisplayIndex : atDisplayIndex, previousList : startList, numChunksBefore: 0).result
    }
    func activeRepeatsIn(_ array : [DataChunk], atDisplayIndex: Int, previousList : [Bool], numChunksBefore: Int) -> (result: [Bool], done : Bool)
    {
        var numChunks = numChunksBefore
        var currentList = previousList
        
        for chunk in array {
            if (numChunks == atDisplayIndex) { return (result: currentList, done : true) }
            if (chunk.type == .Repeat) {
                let dimension = chunk.format.rawValue - DataFormatType.rDimension1.rawValue
                currentList[dimension] = true
                let result = activeRepeatsIn(chunk.repeatChunks!, atDisplayIndex: atDisplayIndex, previousList : currentList, numChunksBefore: numChunks+1)
                if (result.done) { return result }
                currentList[dimension] = false
            }
            else {
                numChunks += 1
            }
        }

        return (result: currentList, done : false)
    }
    
    func insertChunk(_ chunk : DataChunk, atDisplayIndex: Int)
    {
        let _ = insertChunkIn(nil, newChunk : chunk, atDisplayIndex: atDisplayIndex, numChunksBefore: 0)
    }
    func insertChunkIn(_ chunk : DataChunk?, newChunk : DataChunk, atDisplayIndex: Int, numChunksBefore: Int) -> (numChunksAfterSet: Int, inserted: Bool)
    {
        var numChunks = numChunksBefore

        var array = chunks
        if (chunk != nil) { array = chunk!.repeatChunks! }
        
        for index in 0..<array.count {
            if (numChunks == atDisplayIndex) {
                if let chunk = chunk {      //  recursive chunk
                    chunk.repeatChunks!.insert(newChunk, at : index)
                }
                else {     //  main data set
                    chunks.insert(newChunk, at : index)
                }
                return (numChunksAfterSet: numChunks, inserted: true)
            }
            numChunks += 1
            if (array[index].type == .Repeat) {
                let result = insertChunkIn(array[index], newChunk : newChunk, atDisplayIndex : atDisplayIndex, numChunksBefore: numChunks)
                numChunks = result.numChunksAfterSet
                if (result.inserted) { return (numChunksAfterSet: numChunks, inserted : true) }      //  If inserted in subchunk - pass it up
            }
        }

        return (numChunksAfterSet: numChunks, inserted : false)
    }
    
    func insertChunkAfter(_ chunk : DataChunk, atDisplayIndex: Int)
    {
        let _ = insertChunkAfterIn(nil, newChunk : chunk, atDisplayIndex: atDisplayIndex, numChunksBefore: 0)
    }
    func insertChunkAfterIn(_ chunk : DataChunk?, newChunk : DataChunk, atDisplayIndex: Int, numChunksBefore: Int) -> (numChunksAfterSet: Int, inserted: Bool)
    {
        var numChunks = numChunksBefore
        
        var array = chunks
        if (chunk != nil) { array = chunk!.repeatChunks! }
        
        for index in 0..<array.count {
            if (numChunks == atDisplayIndex) {
                if let chunk = chunk {      //  recursive chunk
                    chunk.repeatChunks!.insert(newChunk, at : index+1)
                }
                else {     //  main data set
                    chunks.insert(newChunk, at : index+1)
                }
                return (numChunksAfterSet: numChunks, inserted: true)
            }
            numChunks += 1
            if (array[index].type == .Repeat) {
                let result = insertChunkAfterIn(array[index], newChunk : newChunk, atDisplayIndex : atDisplayIndex, numChunksBefore: numChunks)
                numChunks = result.numChunksAfterSet
                if (result.inserted) { return (numChunksAfterSet: numChunks, inserted : true) }      //  If inserted in subchunk - pass it up
            }
        }
        
        return (numChunksAfterSet: numChunks, inserted : false)
    }

    func replaceChunk(_ chunk : DataChunk, atDisplayIndex: Int)
    {
        let _ = replaceChunkIn(nil, newChunk : chunk, atDisplayIndex: atDisplayIndex, numChunksBefore: 0)
    }
    func replaceChunkIn(_ chunk : DataChunk?, newChunk : DataChunk, atDisplayIndex: Int, numChunksBefore: Int) -> (numChunksAfterSet: Int, replaced: Bool)
    {
        var numChunks = numChunksBefore
        
        var array = chunks
        if (chunk != nil) { array = chunk!.repeatChunks! }
        
        for index in 0..<array.count {
            if (numChunks == atDisplayIndex) {
                if let chunk = chunk {      //  recursive chunk
                    chunk.repeatChunks!.insert(newChunk, at : index)
                    chunk.repeatChunks!.remove(at: index+1)
                }
                else {     //  main data set
                    chunks.insert(newChunk, at : index)
                    chunks.remove(at: index+1)
                }
                return (numChunksAfterSet: numChunks, replaced: true)
            }
            numChunks += 1
            if (array[index].type == .Repeat) {
                let result = replaceChunkIn(array[index], newChunk : newChunk, atDisplayIndex : atDisplayIndex, numChunksBefore: numChunks)
                numChunks += result.numChunksAfterSet
                if (result.replaced) { return (numChunksAfterSet: numChunks, replaced : true) }      //  If inserted in subchunk - pass it up
            }
        }
        
        return (numChunksAfterSet: numChunks, replaced : false)
    }
    
    
    func deleteChunks(fromIndex: Int, toIndex: Int)
    {
        let _ = markForDeleteIn(chunks, fromIndex : fromIndex, toIndex : toIndex, numChunksBefore: 0)
        deleteChunksIn(nil)
    }
    func markForDeleteIn(_ array : [DataChunk], fromIndex : Int, toIndex : Int, numChunksBefore: Int) -> Int
    {
        var numChunks = numChunksBefore
        
        for chunk in array {
            if (numChunks >= fromIndex && numChunks <= toIndex) {
                chunk.length = -1
            }
            numChunks += 1
            if (chunk.type == .Repeat) {
                numChunks = markForDeleteIn(chunk.repeatChunks!, fromIndex : fromIndex, toIndex : fromIndex, numChunksBefore: numChunks)
            }
        }
        
        return numChunks
    }
    func deleteChunksIn(_ chunk : DataChunk?)
    {
        var array = chunks
        if (chunk != nil) { array = chunk!.repeatChunks! }
        
        for index in stride(from: array.count-1, through: 0, by: -1) {
            if (array[index].length < 0) {
                if let chunk = chunk {      //  recursive chunk
                    chunk.repeatChunks?.remove(at: index)
                }
                else {     //  main data set
                    chunks.remove(at: index)
                }
            }
            else {
                if (array[index].type == .Repeat) {
                    deleteChunksIn(array[index])
                }
            }
        }
    }

    func repeatChunks(fromIndex: Int, toIndex: Int, times: Int, forDimension: DataFormatType)
    {
        let _ = addRepeat(nil, fromIndex : fromIndex, toIndex : toIndex, times: times, forDimension: forDimension, numChunksBefore: 0)
    }
    func addRepeat(_ chunk : DataChunk?, fromIndex : Int, toIndex : Int, times: Int, forDimension: DataFormatType, numChunksBefore: Int) -> (numChunksAfterSet: Int, added: Bool)
    {
        var numChunks = numChunksBefore
        var startIndex = -1
        
        var array = chunks
        if (chunk != nil) { array = chunk!.repeatChunks! }
        
        for index in 0..<array.count {
            if (numChunks == fromIndex) {
                startIndex = index
            }
            if (array[index].type == .Repeat) {
                let result = addRepeat(array[index], fromIndex : fromIndex, toIndex : toIndex, times: times, forDimension: forDimension, numChunksBefore: numChunks+1)
                numChunks = result.numChunksAfterSet
                if (result.added) { return (numChunksAfterSet: numChunks, added : true) }      //  Stop if done in subchunk
            }
            else {
                numChunks += 1
            }
            if (numChunks == toIndex+1 && startIndex >= 0) {
                //  Create a repeat chunk
                let repeatChunk = DataChunk(type: .Repeat, length: times, format: forDimension, postProcessing : .None)
                repeatChunk.repeatChunks = []
                //  Move the repeated items into it
                for moveIndex in startIndex...index {
                    repeatChunk.repeatChunks!.append(array[moveIndex])
                }
                if let chunk = chunk {      //  recursive chunk
                    //  Remove the repeated items
                    chunk.repeatChunks!.removeSubrange(startIndex...index)
                    //  Insert the repeat chunk before the start
                    chunk.repeatChunks!.insert(repeatChunk, at: startIndex)
                }
                else {      //  main data set
                    //  Remove the repeated items
                    chunks.removeSubrange(startIndex...index)
                    //  Insert the repeat chunk before the start
                    chunks.insert(repeatChunk, at: startIndex)
                }
                return (numChunksAfterSet: numChunks, added : true)
            }
       }
        
        return (numChunksAfterSet: numChunks, added: false)
    }
    
    func setNormalizationIndex(startIndex : Int) -> Int
    {
        return setNormalizationIndexIn(chunks, startIndex : startIndex)
    }
    func setNormalizationIndexIn(_ array : [DataChunk], startIndex : Int) -> Int
    {
        var currentIndex = startIndex
        
        for chunk in array {
            if (chunk.type == .Repeat) {
                currentIndex = setNormalizationIndexIn(chunk.repeatChunks!, startIndex: currentIndex)
            }
            else if (chunk.type != .SetDimension) {
                if (chunk.postProcessing == .Normalize_All_0_1 || chunk.postProcessing == .Normalize_All_M1_1) {
                    chunk.normalizationIndex = -currentIndex
                    currentIndex += 1
                }
                else if (chunk.postProcessing == .Normalize_0_1 || chunk.postProcessing == .Normalize_M1_1) {
                    chunk.normalizationIndex = currentIndex
                    currentIndex += 1
                }
            }
        }
        
        return currentIndex
    }

    func getChunkColor(_ chunk: DataChunk) -> NSColor
    {
        switch (chunk.type) {
        case .Unused:
            return NSColor(red:0.5, green:0.5, blue:0.5, alpha:1.0)
        case .Label:
            return NSColor(red:1.0, green:1.0, blue:0.8, alpha:1.0)
        case .LabelIndex:
            return NSColor(red:1.0, green:0.9, blue:0.8, alpha:1.0)
        case .Feature:
            return NSColor(red:0.663, green:0.804, blue:0.89, alpha:1.0)
        case .RedValue:
            return NSColor(red:1.0, green:0.8, blue:0.8, alpha:1.0)
        case .GreenValue:
            return NSColor(red:0.8, green:1.0, blue:0.8, alpha:1.0)
        case .BlueValue:
            return NSColor(red:0.8, green:0.8, blue:1.0, alpha:1.0)
        case .OutputValues:
            return NSColor(red:0.929, green:0.733, blue:0.6, alpha:1.0)
        default:
            return NSColor(red:1.0, green:1.0, blue:1.0, alpha:1.0)
       }
    }
  
    func getChunkLabel(_ chunk: DataChunk) -> String
    {
        return chunk.type.typeString
    }

    func parseBinaryFile(trainingData: TrainingData, inputFile : InputStream) -> String?
    {
        //  Process each chunk
        for chunk in chunks {
            if (!chunk.parseBinaryChunk(trainingData: trainingData, inputFile: inputFile)) {
                return trainingData.docData?.loadError
            }
        }
        
        return nil
    }
    
    func parseTextFile(trainingData: TrainingData, textFile : TextFileReader, format : InputFormat)  -> String?
    {
        //  Bypass any skip lines
        if (numSkipLines > 0) {
            for _ in 0..<numSkipLines {
                let line = textFile.readLine()
                if (line == nil) { return "Error reading the specified number of 'skip' lines" }
            }
        }
        
        //  Process lines till the end of the file
        while (true) {
            let line = textFile.readTrimmedLine()
            if (line == nil) { break }
            
            //  See if the line is a comment line
            for indicator in commentIndicators {
                if (line!.hasPrefix(indicator)) { continue }
            }
            
            //  Add a sample
            trainingData.incrementSample()
            
            //  Parse the line based on the format
            switch (format) {
            case .CommaSeparated:
                let components = line!.components(separatedBy: CharacterSet(charactersIn: ","))
                //  Process each chunk
                var componentOffset = 0
                for chunk in chunks {
                     let usedComponents = chunk.parseTextChunk(trainingData: trainingData, components: components, offset : componentOffset)
                    if (usedComponents < 0) {
                        return trainingData.docData?.loadError
                    }
                    componentOffset += usedComponents
                }

            case .SpaceDelimited:
                let components = line!.components(separatedBy: .whitespaces)
                //  Process each chunk
                var componentOffset = 0
                for chunk in chunks {
                    let usedComponents = chunk.parseTextChunk(trainingData: trainingData, components: components, offset : componentOffset)
                    if (usedComponents < 0) {
                        return trainingData.docData?.loadError
                    }
                    componentOffset += usedComponents
                }

            case .FixedColumns:
                //  Process each chunk
                var startIndex = line!.startIndex
                for chunk in chunks {
                    let finalIndex = chunk.parseFixedWidthTextChunk(trainingData: trainingData, string: line!, index : startIndex)
                    if (finalIndex == nil) {
                        return trainingData.docData?.loadError
                    }
                    startIndex = finalIndex!
                }
                
            default:
                return "Coding error - unsupported text format"
            }
        }
        
        return nil
    }

    // MARK: - NSCoding
    required init?(coder aDecoder: NSCoder) {
        let version = aDecoder.decodeInteger(forKey: "fileVersion")
        if (version > 1) { return nil }
        
        chunks = aDecoder.decodeObject(forKey: "chunks") as! [DataChunk]
        numSkipLines = aDecoder.decodeInteger(forKey: "numSkipLines")
        commentIndicators = aDecoder.decodeObject(forKey: "commentIndicators") as! [String]


        super.init()
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(1, forKey: "fileVersion")
        aCoder.encode(chunks, forKey: "chunks")
        aCoder.encode(numSkipLines, forKey: "numSkipLines")
        aCoder.encode(commentIndicators, forKey: "commentIndicators")
    }
    
    
    //  MARK: NSCopying
    func copy(with zone: NSZone? = nil) -> Any {
        fatalError("copyWithZone not implemented")
    }
}

