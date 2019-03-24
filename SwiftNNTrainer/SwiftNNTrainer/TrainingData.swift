//
//  TrainingData.swift
//  SwiftNNTrainer
//
//  Created by Kevin Coble on 2/9/19.
//  Copyright © 2019 Kevin Coble. All rights reserved.
//

import Cocoa

enum ColorChannel : Int {
    case red = 0
    case green = 1
    case blue = 2
    case alpha = 3
    
    var typeString : String
    {
        get {
            switch (self)
            {
            case .red:
                return "Red"
            case .green:
                return "Green"
            case .blue:
                return "Blue"
            case .alpha:
                return "Alpha"
            }
        }
    }
}

class TrainingData
{
    var trainingData : [(input:[Float], output:[Float], outputClass: Int)]
    var testingData : [(input:[Float], output:[Float], outputClass: Int)]
    
    var labels : [String]?
    
    //  Loading variables
    var inputDimensions : [Int]
    var outputDimensions : [Int]
    var docData : DocumentData?
    var inputSize : Int
    var outputSize : Int
    var loadingTrainingData = true
    var currentSample = -1
    var currentInputLocation : [Int]
    var currentOutputLocation : [Int]
    var inputLocationOffsets : [Int]     //  Offsets into array for each dimension
    var outputLocationOffsets : [Int]     //  Offsets into array for each dimension
    var inputNormalizationMap : [Int]
    var outputNormalizationMap : [Int]

    init? (docData : DocumentData)
    {
        trainingData = []
        testingData = []
        currentSample = -1
        self.docData = docData
        docData.loadedTrainingSamples.value = 0
        docData.loadedTestingSamples.value = 0
        inputDimensions = docData.inputDimensions
        outputDimensions = docData.outputDimensions
        inputSize = inputDimensions.reduce(1, *)
        outputSize = outputDimensions.reduce(1, *)
        currentInputLocation = [0, 0, 0, 0]
        currentOutputLocation = [0, 0, 0, 0]
        inputLocationOffsets = [1, inputDimensions[0], inputDimensions[0] * inputDimensions[1], inputDimensions[0] * outputDimensions[1] * inputDimensions[2]]
        outputLocationOffsets = [1, outputDimensions[0], outputDimensions[0] * outputDimensions[1], outputDimensions[0] * outputDimensions[1] * outputDimensions[2]]
        inputNormalizationMap = [Int](repeating: 0, count: inputSize)
        outputNormalizationMap = [Int](repeating: 0, count: outputSize)

        //  If images in a folder - validate the channel dimension
        if (docData.inputFormat == .ImagesInFolders) {
            if (inputDimensions[2] != 1 && inputDimensions[2] != 3) {
                docData.loadError = "For 'Images in Folders', channel dimension (input dimension 3) must be 1 or 3"
                return nil
            }
        }
        
        //  If a label file, start with it (labels may be in output data later)
        if (docData.outputType == .Classification) { labels = [] }
        if (docData.separateLabelFile) {
            if (!loadLabels()) { return nil }
        }
        
        //  Set up the normalization map
        var nextIndex = 1
        if let parser = docData.inputDataParser {
            nextIndex = parser.setNormalizationIndex(startIndex: nextIndex)
        }
        if let parser = docData.outputDataParser {
            nextIndex = parser.setNormalizationIndex(startIndex: nextIndex)
        }

        //  Load the main input (possibly output) file
        if (docData.stopLoading.state) { return nil }
        loadingTrainingData = true
        DispatchQueue.main.async {
            docData.loadingStatus = "Loading Training Input Data"
        }
        switch (docData.trainingDataInputSource) {
            case .Generated:
                generateData(inputDimensions: docData.inputDimensions, outputDimensions: docData.outputDimensions)
            
            case .EnclosingFolder:
                if !(getDataFromFolder(format: docData.inputFormat, url: docData.trainingInputDataURL, parser: docData.inputDataParser, folderType: "Training Input")) { return nil }
            
            case .File:
                if !(getDataFromFile(format: docData.inputFormat, url: docData.trainingInputDataURL, parser: docData.inputDataParser, fileType: "Training Input")) { return nil }
        }
        
        //  If separate output source, read it
        if (docData.stopLoading.state) { return nil }
        if (docData.separateOutputSource) {
            DispatchQueue.main.async {
                docData.loadingStatus = "Loading Training Output Data"
            }
            currentSample = -1
            switch (docData.trainingDataOutputSource) {
            case .EnclosingFolder:
                if !(getDataFromFolder(format: docData.outputFormat, url: docData.trainingOutputDataURL, parser: docData.outputDataParser, folderType: "Training Output")) { return nil }

            case .File:
                if !(getDataFromFile(format: docData.outputFormat, url: docData.trainingOutputDataURL, parser: docData.outputDataParser, fileType: "Training Output")) { return nil }

            default:
                fatalError("Invalid output source type")
           }
        }
        
        //  If a separate testing source, read it
        if (docData.stopLoading.state) { return nil }
        if (docData.separateTestingSource) {
            DispatchQueue.main.async {
                docData.loadingStatus = "Loading Testing Input Data"
            }
            loadingTrainingData = false
            currentSample = -1
            currentInputLocation = [0, 0, 0, 0]
            currentOutputLocation = [0, 0, 0, 0]
            switch (docData.trainingDataInputSource) {
            case .EnclosingFolder:
                if !(getDataFromFolder(format: docData.inputFormat, url: docData.testingInputDataURL, parser: docData.inputDataParser, folderType: "Testing Input")) { return nil }

            case .File:
                if !(getDataFromFile(format: docData.inputFormat, url: docData.testingInputDataURL, parser: docData.inputDataParser, fileType: "Testing Input")) { return nil }

            default:
                fatalError("Invalid input source type for seperate testing source")
            }
            
            //  If separate output source, read it
            if (docData.stopLoading.state) { return nil }
            if (docData.separateOutputSource) {
                DispatchQueue.main.async {
                    docData.loadingStatus = "Loading Testing Output Data"
                }
                currentSample = -1
                switch (docData.trainingDataOutputSource) {
                case .EnclosingFolder:
                    if !(getDataFromFolder(format: docData.outputFormat, url: docData.testingOutputDataURL, parser: docData.outputDataParser, folderType: "Testing Output")) { return nil }

                case .File:
                    if !(getDataFromFile(format: docData.outputFormat, url: docData.testingOutputDataURL, parser: docData.outputDataParser, fileType: "Testing Output")) { return nil }
                    
                default:
                    fatalError("Invalid output source type")
                }
            }

        }
        
        //  Get a concurrent queue for normalization
        let concurrentQueue = DispatchQueue.global(qos: .userInitiated)
        let serialQueue = DispatchQueue(label: "com.macrobotic.serialdataupdate")
        serialQueue.suspend()
        
        //  Check the normalization map, and normalize if called for
        DispatchQueue.main.async {
            docData.loadingStatus = "Normalizing Data"
        }
        var startIndex = 0
        while (true) {
            var indices : [Int] = []
            //  Find the first index that still needs normalization
            for i in startIndex..<inputSize {
                if (inputNormalizationMap[i] != 0) {
                    indices.append(i)
                    inputNormalizationMap[i] = 0
                    startIndex = i+1
                    if (startIndex >= inputSize) { break }
                    //  Find all the other ones that need the same normalization
                    for j in (startIndex+1)..<inputSize {
                        if (inputNormalizationMap[j] == inputNormalizationMap[i]) {
                            indices.append(j)
                            inputNormalizationMap[j] = 0
                        }
                    }
                    break
                }
            }
            if (indices.count == 0) { break }
            
            //  Start a normalization task on a concurrent queue for the given indices
            concurrentQueue.async {
                self.normalizeInputData(indices : indices, updateQueue: serialQueue)
            }
        }
        startIndex = 0
        while (true) {
            var indices : [Int] = []
            //  Find the first index that still needs normalization
            for i in startIndex..<outputSize {
                if (outputNormalizationMap[i] != 0) {
                    indices.append(i)
                    outputNormalizationMap[i] = 0
                    startIndex = i+1
                    if (startIndex >= outputSize) { break }                    //  Find all the other ones that need the same normalization
                    for j in (startIndex+1)..<outputSize {
                        if (outputNormalizationMap[j] == outputNormalizationMap[i]) {
                            indices.append(j)
                            outputNormalizationMap[j] = 0
                        }
                    }
                    break
                }
            }
            if (indices.count == 0) { break }
            
             //  Start a normalization task on a concurrent queue for the given indices
            concurrentQueue.async {
                self.normalizeOutputData(indices : indices, updateQueue: serialQueue)
            }
        }
        
        serialQueue.resume()

        //  Wait for the normalization tasks to be done
        serialQueue.sync {
            DispatchQueue.main.async {
                docData.loadingStatus = "Done Normalizing Data"
            }
        }

        //  If we are to partition some of the training samples into testing samples, now is the time
        if (docData.createTestDataFromTrainingData) {
            DispatchQueue.main.async {
                docData.loadingStatus = "Splitting Out Testing Data"
            }
            let numToTransfer = Int(docData.testDataPercentage * Float(trainingData.count) + 0.5)
            
            //  Transfer the samples
            if (numToTransfer > 0) {
                switch (docData.testDataSourceLocation) {
                case .Beginning:
                    testingData = Array(trainingData[0..<numToTransfer])
                    trainingData = Array(trainingData[numToTransfer..<trainingData.count])

                case .Random:
                    let indices = 0..<trainingData.count
                    let shuffledIndices = indices.shuffled()
                    testingData = []
                    var newTrainingData : [(input:[Float], output:[Float], outputClass: Int)] = []
                    for i in 0..<numToTransfer {
                        testingData.append(trainingData[shuffledIndices[i]])
                    }
                    for i in numToTransfer..<trainingData.count {
                        newTrainingData.append(trainingData[shuffledIndices[i]])
                    }
                    trainingData = newTrainingData

                case .End:
                    testingData = Array(trainingData[(trainingData.count - numToTransfer)..<trainingData.count])
                    trainingData = Array(trainingData[0..<(trainingData.count - numToTransfer)])
                }
                
                //  Update the display variables
                docData.loadedTrainingSamples.value = self.trainingData.count
                docData.loadedTestingSamples.value = self.testingData.count
            }
        }
    }
    
    func loadLabels() -> Bool
    {
        //  Verify a file has been selected
        if (docData!.labelFileURL == nil) {
            docData!.loadError = "No label file URL has been set"
            return false
        }
        
        do {
            let fileData = try String(contentsOf: docData!.labelFileURL!, encoding: .utf8)
            let lines : [String] = fileData.components(separatedBy: CharacterSet.newlines)
            labels = lines.filter { $0.count > 0}
        }
        catch {
            docData!.loadError = "Unable to read label file"
            return false
        }
        return false
    }
    
    func getDataFromFile(format : InputFormat, url: URL?, parser: DataParser?, fileType: String) -> Bool
    {
        //  Verify a file has been selected
        if (url == nil) {
            docData!.loadError = "No " + fileType + " Source Path has been set"
            return false
        }

        //  Process binary files
        if (format == .Binary) {
            //  Open the file
            guard let inputStream = InputStream(url: url!) else {
                docData!.loadError = "Unable to open " + fileType + " source path"
                return false
            }
            if let error = inputStream.streamError {
                docData!.loadError = "Unable to open " + fileType + " source path - " + error.localizedDescription
                return false
            }
            
            //  Get the parser
            if let parser = parser {
                inputStream.open()
                if let error = parser.parseBinaryFile(trainingData: self, inputFile : inputStream) {
                    docData!.loadError = error
                    return false
                }
                inputStream.close()
            }
            else {
                docData!.loadError = "No Parser defined for the output data"
                return false
            }
        }
        
        //  Process text files
        else {
            //  Open the file
            guard let reader = TextFileReader(inFileURL: url!) else {
                docData!.loadError = "Unable to open " + fileType + " source path"
                return false
            }
            
            //  Get the parser
            if let parser = parser {
                if let error = parser.parseTextFile(trainingData: self, textFile : reader, format : format) {
                    docData!.loadError = error
                    return false
                }
            }
            else {
                docData!.loadError = "No Parser defined for the output data"
                return false
            }
         }
        
        return true
    }
    
    
    func getDataFromFolder(format : InputFormat, url: URL?, parser: DataParser?, folderType: String) -> Bool
    {
        //  Verify a folder has been selected
        if (url == nil) {
            docData!.loadError = "No " + folderType + " Source Path has been set"
            return false
        }

        //  Verify the folder exists
        let fileManager = FileManager.default
        if (!fileManager.fileExists(atPath: (url?.path)!)) {
            docData!.loadError = "Specified URL for " + folderType + " does not exist locally"
            return false
        }

        //  If not images in folders, process each file in the folder
        if (format != .ImagesInFolders) {
            do {
                //  Get the list of files in the folder
                let files = try fileManager.contentsOfDirectory(at: url!, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                
                //  Process each file
                for file in files {
                    let components = file.pathComponents
                    if (components.count < 1) { continue }
                    let name = components.last!
                    DispatchQueue.main.async {
                        self.docData!.loadingStatus = "Loading data from file " + name
                    }
                    if (!getDataFromFile(format : format, url: file, parser: parser, fileType: folderType)) { return false }
                }

            } catch {
                self.docData!.loadError = "directoryEnumerator error at \(url!): " + error.localizedDescription
                return false
            }

        }
        
        //  Process as images in folders
        else {
            do {
                //  Get the subfolders
                let subFolders = try fileManager.contentsOfDirectory(at: url!, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                
                //  Process each subfolder
                for folder in subFolders {
                    let components = folder.pathComponents
                    if (components.count < 1) { continue }
                    let label = components.last!
                    DispatchQueue.main.async {
                        self.docData!.loadingStatus = "Loading images from directory " + label
                    }
                    var labelIndex = 0
                    
                    var foundLabel = false
                    if let labels = labels {
                        for index in 0..<labels.count {
                            if(labels[index].caseInsensitiveCompare(label) == .orderedSame) {
                                labelIndex =  index
                                foundLabel = true
                                break
                            }
                        }
                    }
                    if (!foundLabel) {
                        labelIndex = labels!.count
                        labels!.append(label)
                    }
                    
                    //  Validate the label
                    if (labelIndex >= outputSize) {
                        docData?.loadError = "More labels (from folder names) than will fit in output dimensions"
                        return false
                    }
                    
                    //  Get the output array
                    var outputArray = [Float](repeating: 0.0, count: outputSize)
                    outputArray[labelIndex] = 1.0
                    
                    //  Process each file in the folder
                    let fileList = try fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                    for file in fileList {
                        if let image = NSImage(contentsOf: file) {
                            let data = convertImageToData(image)
                            if (data.count <= 0) { return false }
                            if (loadingTrainingData) {
                                trainingData.append((input: data, output: outputArray, outputClass: labelIndex))
                            }
                            else {
                                testingData.append((input: data, output: outputArray, outputClass: labelIndex))
                           }
                        }
                        else {
                            docData!.loadError = "File " + file.absoluteString + " could not be read into an image"
                            return false
                       }
                    }
                }
                
            } catch {
                self.docData!.loadError = "directoryEnumerator error at \(url!): " + error.localizedDescription
                return false
            }
        }
        
        return true
    }
    
    func incrementSample()
    {
        currentSample += 1
        
        //  If needed, create a new sample
        if (loadingTrainingData) {
            if (currentSample >= trainingData.count) { addSample() }
        }
        else {
            if (currentSample >= testingData.count) { addSample() }
        }
    }
    func addSample()
    {
        let inputArray = [Float](repeating: 0.0, count: inputSize)
        let outputArray = [Float](repeating: 0.0, count: outputSize)
        let sample = (input:inputArray, output:outputArray, outputClass: 0)
        if (loadingTrainingData) {
            trainingData.append(sample)
            docData!.loadedTrainingSamples.increment()
        }
        else {
            testingData.append(sample)
            docData!.loadedTestingSamples.increment()
        }
        
        //  Store location starts at the beginning for the sample
        currentInputLocation = [0, 0, 0, 0]
        currentOutputLocation = [0, 0, 0, 0]
    }
    
    func appendOutputClass(_ sampleClass : Int) -> Bool {
        if (docData!.stopLoading.state) { return false }       //  Check for load abort
        //  Validate the class fits with the output size
        if (sampleClass < 0 || ((sampleClass != 1 || outputSize != 1) && sampleClass >= outputSize)) {
            docData?.loadError = "Sample class index of \(sampleClass) is outside of output dimensions"
            return false
        }
        //  Set the class and output data
        if (loadingTrainingData) {
            trainingData[currentSample].outputClass = sampleClass
            if (outputSize > 1) {
                trainingData[currentSample].output[sampleClass] = 1.0
            }
            else {
                if (sampleClass == 1) { trainingData[currentSample].output[0] = 1.0 }
            }
        }
        else {
            testingData[currentSample].outputClass = sampleClass
            if (outputSize > 1) {
                testingData[currentSample].output[sampleClass] = 1.0
            }
            else {
                if (sampleClass == 1) { testingData[currentSample].output[0] = 1.0 }
            }
        }
        return true
    }
    
    func appendInputData(_ inputArray : [Float], normalizationIndex : Int?) -> Bool
    {
        if (docData!.stopLoading.state) { return false }       //  Check for load abort
        for newValue in inputArray {
            //  Verify we are in range
            if (!inputLocationInRange()) { return false }
            //  Store the value
            let index = currentInputLocation[0] + currentInputLocation[1] * inputLocationOffsets[1] + currentInputLocation[2] * inputLocationOffsets[2] + currentInputLocation[3] * inputLocationOffsets[3]
            if (loadingTrainingData) {
                trainingData[currentSample].input[index] = newValue
                if (currentSample == 0 && inputNormalizationMap[index] == 0) {
                    if let normIndex = normalizationIndex {
                        if (normIndex > 0) {
                            inputNormalizationMap[index] = normIndex
                        }
                        else {
                            for i in 0..<inputSize { inputNormalizationMap[i] = normIndex }
                        }
                    }
                }
            }
            else {
                testingData[currentSample].input[index] = newValue
            }
            //  Increment the location
            currentInputLocation[0] += 1
        }
        return true
    }
    
    func appendColorData(_ inputArray : [Float], channel: ColorChannel, normalizationIndex : Int?) -> Bool
    {
        if (docData!.stopLoading.state) { return false }       //  Check for load abort
        for newValue in inputArray {
            //  Set the color as the third dimension (X-Y pixel grid)
            currentInputLocation[2] = channel.rawValue
            if (currentInputLocation[2] >= inputDimensions[2]) {
                docData?.loadError = "Color channel " + channel.typeString + " outside range of dimension 3"
                return false
            }
            //  Verify we are in range
            if (!inputLocationInRange()) { return false }
            //  Store the value
            let index = currentInputLocation[0] + currentInputLocation[1] * inputLocationOffsets[1] + currentInputLocation[2] * inputLocationOffsets[2] + currentInputLocation[3] * inputLocationOffsets[3]
            if (loadingTrainingData) {
                trainingData[currentSample].input[index] = newValue
                if (currentSample == 0 && inputNormalizationMap[index] == 0) {
                    if let normIndex = normalizationIndex {
                        if (normIndex > 0) {
                            inputNormalizationMap[index] = normIndex
                        }
                        else {
                            for i in 0..<inputSize { inputNormalizationMap[i] = normIndex }
                        }
                    }
                }
            }
            else {
                testingData[currentSample].input[index] = newValue
            }
            //  Increment the location
            currentInputLocation[0] += 1
        }
        return true
    }
    
    func appendOutputData(_ outputArray : [Float], normalizationIndex : Int?) -> Bool
    {
        if (docData!.stopLoading.state) { return false }       //  Check for load abort
        for newValue in outputArray {
            //  Verify we are in range
            if (!outputLocationInRange()) { return false }
            //  Store the value
            let index = currentOutputLocation[0] + currentOutputLocation[1] * outputLocationOffsets[1] + currentOutputLocation[2] * outputLocationOffsets[2] + currentOutputLocation[3] * outputLocationOffsets[3]
            if (loadingTrainingData) {
                trainingData[currentSample].output[index] = newValue
                if (currentSample == 0 && inputNormalizationMap[index] == 0) {
                    if let normIndex = normalizationIndex {
                        if (normIndex > 0) {
                            outputNormalizationMap[index] = normIndex
                        }
                        else {
                            for i in 0..<inputSize { outputNormalizationMap[i] = normIndex }
                        }
                    }
                }
            }
            else {
                testingData[currentSample].output[index] = newValue
            }
            //  Increment the location
            currentOutputLocation[0] += 1
        }
        return true
    }
    
    func inputLocationInRange() -> Bool
    {
        for i in 0..<4 {
            if (currentInputLocation[i] >= inputDimensions[i]) {
                docData?.loadError = "Input data size exceeded for dimension \(i)"
                return false
            }
        }
        return true
    }
    func outputLocationInRange() -> Bool
    {
        for i in 0..<4 {
            if (currentOutputLocation[i] >= outputDimensions[i]) {
                docData?.loadError = "Output data size exceeded for dimension \(i)"
                return false
            }
        }
        return true
    }
    
    func convertImageToData(_ image : NSImage) -> [Float]
    {
        if (docData!.stopLoading.state) { return [] }       //  Check for load abort
        //  Get the number of channels to be set
        var samples = 1
        var colorSpace = NSColorSpaceName.calibratedWhite
        var hasAlpha = false
        if (inputDimensions[2] > 1) {
            samples = 4
            colorSpace = NSColorSpaceName.calibratedRGB
            hasAlpha = true
        }
        
        //  Resize the image to input dimensions and channel width
        let scaledBitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: inputDimensions[0], pixelsHigh: inputDimensions[1], bitsPerSample: 8, samplesPerPixel: samples,
                        hasAlpha: hasAlpha, isPlanar: false, colorSpaceName: colorSpace, bytesPerRow: 0, bitsPerPixel: samples * 8)
        if let representation = scaledBitmap {
            if let context = NSGraphicsContext(bitmapImageRep: representation) {
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = context
                context.imageInterpolation = .high
                let width = CGFloat(inputDimensions[0])
                let height = CGFloat(inputDimensions[1])
                image.draw(in: CGRect(x: 0, y: 0, width: width, height: height), from: CGRect(origin: NSZeroPoint, size: image.size), operation: .copy, fraction: 1.0 )
                context.flushGraphics()
                NSGraphicsContext.restoreGraphicsState()
                
//                let scaleImage = NSImage(size: NSSize(width: inputDimensions[0], height: inputDimensions[1]))
//                scaleImage.addRepresentation(representation)
                
                //  Convert the image to floats
                var data = [Float](repeating: 0.0, count: inputSize)
                let normalizer = 1.0 / Float(255)
                let rowBytes = representation.bytesPerRow
                let channelOffset = inputDimensions[0] * inputDimensions[1]
                if let pixels = representation.bitmapData {
                    var posIndex = 0
                    for y in 0..<inputDimensions[1] {
                        var pixelOffset = y * rowBytes
                        for _ in 0..<inputDimensions[0] {
                            var index = posIndex
                            for channel in 0..<samples {
                                if (channel < inputDimensions[2]) {
                                    data[index] = Float(pixels[pixelOffset]) * normalizer
                                    index += channelOffset
                                }
                                pixelOffset += 1
                            }
                            posIndex += 1
                        }
                    }
                }
                
                return data
            }
        }
        
        docData?.loadError = "Error converting image to data"

        return []      //  Error condition
    }
    
    func normalizeInputData(indices : [Int], updateQueue : DispatchQueue)
    {
        //  Find the range of the data
        var minimum = Float.infinity
        var maximum = -Float.infinity
        for i in 0..<trainingData.count {
            for index in indices {
                if (trainingData[i].input[index] < minimum) { minimum = trainingData[i].input[index] }
                if (trainingData[i].input[index] > maximum) { maximum = trainingData[i].input[index] }
            }
        }
        for i in 0..<testingData.count {
            for index in indices {
                if (testingData[i].input[index] < minimum) { minimum = testingData[i].input[index] }
                if (testingData[i].input[index] > maximum) { maximum = testingData[i].input[index] }
            }
        }

        //  Calculate a multiplier
        var multiplier : Float
        if (maximum == minimum) {
            multiplier = 1.0 / maximum
            minimum = 0
        }
        else {
            multiplier = 1.0 / (maximum - minimum)
        }
        
        //  Put the update on a serial queue
        updateQueue.sync {
            updateInputData(indices : indices, minimum : minimum, multiplier : multiplier)
        }
    }
    func updateInputData(indices : [Int], minimum : Float, multiplier : Float) {
        //  Normalize all the values
        for i in 0..<trainingData.count {
            for index in indices {
                trainingData[i].input[index] = (trainingData[i].input[index] - minimum) * multiplier
            }
        }
        for i in 0..<testingData.count {
            for index in indices {
                testingData[i].input[index] = (trainingData[i].input[index] - minimum) * multiplier
            }
        }
    }
    
    func normalizeOutputData(indices : [Int], updateQueue : DispatchQueue)
    {
        //  Find the range of the data
        var minimum = Float.infinity
        var maximum = -Float.infinity
        for i in 0..<trainingData.count {
            for index in indices {
                if (trainingData[i].output[index] < minimum) { minimum = trainingData[i].output[index] }
                if (trainingData[i].output[index] > maximum) { maximum = trainingData[i].output[index] }
            }
        }
        for i in 0..<testingData.count {
            for index in indices {
                if (testingData[i].output[index] < minimum) { minimum = testingData[i].output[index] }
                if (testingData[i].output[index] > maximum) { maximum = testingData[i].output[index] }
            }
        }
        
        //  Calculate a multiplier
        var multiplier : Float
        if (maximum == minimum) {
            multiplier = 1.0 / maximum
            minimum = 0
        }
        else {
            multiplier = 1.0 / (maximum - minimum)
        }
        
        //  Put the update on a serial queue
        updateQueue.sync {
            updateOutputData(indices : indices, minimum : minimum, multiplier : multiplier)
        }
    }
    func updateOutputData(indices : [Int], minimum : Float, multiplier : Float) {
        //  Normalize all the values
        for i in 0..<trainingData.count {
            for index in indices {
                trainingData[i].output[index] = (trainingData[i].output[index] - minimum) * multiplier
            }
        }
        for i in 0..<testingData.count {
            for index in indices {
                testingData[i].output[index] = (trainingData[i].output[index] - minimum) * multiplier
            }
        }

    }

    func getTrainingSample(sampleNumber : Int) -> (input:[Float], output:[Float], outputClass: Int)?
    {
        if (sampleNumber < 0 || sampleNumber >= trainingData.count) { return nil }
        
        return trainingData[sampleNumber]
    }
    
    func getTestingSample(sampleNumber : Int) -> (input:[Float], output:[Float], outputClass: Int)?
    {
        if (sampleNumber < 0 || sampleNumber >= testingData.count) { return nil }
        
        return testingData[sampleNumber]
    }
    
    //  Routine to generate data for network testing - modify as needed for your internal testing
    func generateData(inputDimensions: [Int], outputDimensions: [Int])
    {
        let numTraining = 1000
        let numTesting = 100
        
        let numInputs = inputDimensions.reduce(1, *)
        let numOutputs = outputDimensions.reduce(1, *)
        
        //  If 2 inputs and 1 output, make it an 'or' function test
        if (numInputs == 2 && numOutputs == 1) {
            for _ in 0..<numTraining {
                let input = [Float.random(in: 0 ... 1), Float.random(in: 0 ... 1)]
                let outputClass : Int = (input[0] > 0.5 || input[1] > 0.5) ? 1 : 0
                trainingData.append((input:input, output:[Float(outputClass)], outputClass: outputClass))
            }
            for _ in 0..<numTesting {
                let input = [Float.random(in: 0 ... 1), Float.random(in: 0 ... 1)]
                let outputClass : Int = (input[0] > 0.5 || input[1] > 0.5) ? 1 : 0
                testingData.append((input:input, output:[Float(outputClass)], outputClass: outputClass))
            }
        }

        //  Otherwise, just a random data set
        else {
            for _ in 0..<numTraining {
                var input = [Float](repeating: 0.0, count: numInputs)
                for i in 0..<numInputs {input[i] = Float.random(in: 0 ... 1)}
                var output = [Float](repeating: 0.0, count: numOutputs)
                for i in 0..<numOutputs {output[i] = Float.random(in: 0 ... 1)}
                var outputClass = Int((Float(arc4random()) / Float(UINT32_MAX)) * Float(numOutputs)) + 1
                if (outputClass >= numOutputs)  { outputClass -= 1 }
                trainingData.append((input:input, output:output, outputClass: outputClass))
            }
            for _ in 0..<numTesting {
                var input = [Float](repeating: 0.0, count: numInputs)
                for i in 0..<numInputs {input[i] = Float.random(in: 0 ... 1)}
                var output = [Float](repeating: 0.0, count: numOutputs)
                for i in 0..<numOutputs {output[i] = Float.random(in: 0 ... 1)}
                if (numOutputs == 1) {
                    testingData.append((input:input, output:output, outputClass: Int.random(in: 0 ... 1)))
                }
                else {
                    testingData.append((input:input, output:output, outputClass: Int.random(in: 1 ... numOutputs)))
                }
            }
        }
    }
}
