//
//  Document.swift
//  SwiftNNTrainer
//
//  Created by Kevin Coble on 2/6/19.
//  Copyright © 2019 Kevin Coble. All rights reserved.
//

import Cocoa
import MetalPerformanceShaders
import MetalKit

enum InputDataSource : Int {
    case Generated = 1
    case EnclosingFolder = 2
    case File = 3
}

enum InputFormat : Int {
    case FixedColumns = 1
    case CommaSeparated = 2
    case SpaceDelimited = 3
    case ImagesInFolders = 4
    case Binary = 5
}

enum OutputType : Int {
    case Classification = 1
    case Regression = 2
}

enum TestDataSourceLocation: Int {
    case Beginning = 1
    case Random = 2
    case End = 3
}

enum BatchIndicesSource: Int {
    case sequential = 1
    case batchRandom = 2
    case testSetRandom = 3
}


// MARK: - DocumentData

class DocumentData : NSObject, NSCoding
{
    //  Data dimensions
    var inputDimensions : [Int]
    var outputDimensions : [Int]
    
    //  Output type
    var outputType : OutputType

    //  Input source
    var trainingDataInputSource : InputDataSource
    var trainingInputDataURL : URL?
    var separateTestingSource : Bool
    var testingInputDataURL : URL?
    
    //  Split flag
    var splitChannelsIntoFlows : Bool

    //  Input format
    var inputFormat : InputFormat
    var inputDataParser : DataParser?
    
    //  Output source
    var separateOutputSource : Bool
    var trainingDataOutputSource : InputDataSource
    var trainingOutputDataURL : URL?
    var testingOutputDataURL : URL?
    
    //  Output format
    var outputFormat : InputFormat
    var outputDataParser : DataParser?
    
    //  Label source
    var separateLabelFile : Bool
    var labelFileURL : URL?
    
    //  Test data creation
    var createTestDataFromTrainingData : Bool
    var testDataPercentage : Float
    var testDataSourceLocation : TestDataSourceLocation

    //  Loading error
    var loadError : String?
    var stopLoading = AtomicBool(false)
    var loadedTrainingSamples = AtomicInteger(0)
    var loadedTestingSamples = AtomicInteger(0)
    var loadingStatus = "Not Loaded"

    //  Current network flows
    var flows : [Flow]
    var outputFlow : Int
    
    //  Loss function
    var lossType : MPSCNNLossType
    
    //  Flags
    var needsWeightInitialization : Bool
    
    //  Training parameters
    var batchSize : Int
    var batchIndicesSource : BatchIndicesSource
    var numEpochs : Int
    var testAfterEpoch : Bool
    var epochsBetweenTests : Int
    var useSubsetForTest : Bool
    var testSubsetSize : Int
    var learningRate : Float
    var totalTrainingSamples : Int

    override init() {
        inputDimensions = [10, 1, 1, 1]
        outputDimensions = [10, 1, 1, 1]
        
        splitChannelsIntoFlows = false
        
        trainingDataInputSource = .Generated
        separateTestingSource = false
        inputFormat = .Binary
        
        separateOutputSource = false
        trainingDataOutputSource = .File
        outputFormat = .Binary
        
        separateLabelFile = false
        
        createTestDataFromTrainingData = false
        testDataPercentage = 0.1
        testDataSourceLocation = .Beginning
        
        flows = []
        let firstFlow = Flow()
        flows.append(firstFlow)
        firstFlow.inputs.append(InputSource(type: .Input, index: 0))
        outputFlow = 0
        
        outputType = .Classification
        
        lossType = .meanSquaredError
        
        needsWeightInitialization = true
        
        batchSize = 1
        batchIndicesSource = .batchRandom
        numEpochs = 100
        testAfterEpoch = true
        epochsBetweenTests = 1
        useSubsetForTest = false
        testSubsetSize = 0
        learningRate = 0.01
        totalTrainingSamples = 0

        super.init()
        
        updateFlowDimensions()
    }
    
    func updateFlowDimensions()
    {
        //  Clear the current dimensions
        for flow in flows {
            flow.currentInputSize = [-1, -1, -1, -1]
            flow.currentOutputSize = [-1, -1, -1, -1]
        }
        
        //  Start by setting those that only have data inputs
        for flow in flows {
            if (flow.usesOnlyDataInput) {
                flow.updateDimensionsFromData(self)
            }
        }
        
        //  Iteratively do the rest, stopping when no changes are discovered
        var somethingChanged = true
        while (somethingChanged) {
            somethingChanged = false
            for flow in flows {
                if (!flow.usesOnlyDataInput) {
                    if (flow.updateDimensionsFromData(self)) { somethingChanged = true }
                }
            }
        }
    }
    
    func getFlowInputDimensions(flowIndex : Int) -> [Int]
    {
        if (flowIndex < 0 || flowIndex >= flows.count) { return [-1, -1, -1, -1] }
        return flows[flowIndex].currentInputSize
    }
    func getFlowOutputDimensions(flowIndex : Int) -> [Int]
    {
        if (flowIndex < 0 || flowIndex >= flows.count) { return [-1, -1, -1, -1] }
        return flows[flowIndex].currentOutputSize
    }
    
    func duplicateFlow(_ fromFlow: Int, toFlow: Int)
    {
        if (fromFlow < 0 || fromFlow >= flows.count) { return }
        if (toFlow < 0 || toFlow >= flows.count) { return }
        
        //  Remove all the layers in the destination flow
        flows[toFlow].layers.removeAll()
        
        //  Make copies of the source flow layers and add to the destination flow
        for layer in flows[fromFlow].layers {
            let copy = Layer()
            copy.setFrom(layer: layer)
            flows[toFlow].layers.append(copy)
        }
    }

    // MARK: NSCoding

    required init?(coder aDecoder: NSCoder) {
        let version = aDecoder.decodeInteger(forKey: "fileVersion")
        if (version > 1) { return nil }
        
        inputDimensions = aDecoder.decodeObject(forKey: "inputDimensions") as! [Int]
        outputDimensions = aDecoder.decodeObject(forKey: "outputDimensions") as! [Int]
        
        splitChannelsIntoFlows = aDecoder.decodeBool(forKey: "splitChannelsIntoFlows")
        
        trainingDataInputSource = InputDataSource(rawValue: aDecoder.decodeInteger(forKey: "trainingDataInputSource"))!
        trainingInputDataURL = aDecoder.decodeObject(forKey: "trainingInputDataURL") as! URL?
        separateTestingSource = aDecoder.decodeBool(forKey: "separateTestingSource")
        testingInputDataURL = aDecoder.decodeObject(forKey: "testingInputDataURL") as! URL?
        
        inputFormat = InputFormat(rawValue: aDecoder.decodeInteger(forKey: "inputFormat"))!
        inputDataParser = aDecoder.decodeObject(forKey: "inputDataParser") as! DataParser?
        
        separateOutputSource = aDecoder.decodeBool(forKey: "separateOutputSource")
        trainingDataOutputSource = InputDataSource(rawValue: aDecoder.decodeInteger(forKey: "trainingDataOutputSource"))!
        trainingOutputDataURL = aDecoder.decodeObject(forKey: "trainingOutputDataURL") as! URL?
        testingOutputDataURL = aDecoder.decodeObject(forKey: "testingOutputDataURL") as! URL?
        
        outputFormat = InputFormat(rawValue: aDecoder.decodeInteger(forKey: "outputFormat"))!
        outputDataParser = aDecoder.decodeObject(forKey: "outputDataParser") as! DataParser?

        separateLabelFile = aDecoder.decodeBool(forKey: "separateLabelFile")
        labelFileURL = aDecoder.decodeObject(forKey: "labelFileURL") as! URL?
        
        createTestDataFromTrainingData = aDecoder.decodeBool(forKey: "createTestDataFromTrainingData")
        testDataPercentage = aDecoder.decodeFloat(forKey: "testDataPercentage")
        testDataSourceLocation = TestDataSourceLocation(rawValue: aDecoder.decodeInteger(forKey: "testDataSourceLocation"))!

        flows = aDecoder.decodeObject(forKey: "flows") as! [Flow]
        outputFlow = aDecoder.decodeInteger(forKey: "outputFlow")

        outputType = OutputType(rawValue: aDecoder.decodeInteger(forKey: "outputType"))!
        lossType = MPSCNNLossType(rawValue: aDecoder.decodeObject(forKey: "lossType") as! UInt32)!
        needsWeightInitialization = aDecoder.decodeBool(forKey: "needsWeightInitialization")
        batchSize = aDecoder.decodeInteger(forKey: "batchSize")
        batchIndicesSource = BatchIndicesSource(rawValue: aDecoder.decodeInteger(forKey: "batchIndicesSource"))!
        numEpochs = aDecoder.decodeInteger(forKey: "numEpochs")
        testAfterEpoch = aDecoder.decodeBool(forKey: "testAfterEpoch")
        epochsBetweenTests = aDecoder.decodeInteger(forKey: "epochsBetweenTests")
        useSubsetForTest = aDecoder.decodeBool(forKey: "useSubsetForTest")
        testSubsetSize = aDecoder.decodeInteger(forKey: "testSubsetSize")
        learningRate = aDecoder.decodeFloat(forKey: "learningRate")
        totalTrainingSamples = aDecoder.decodeInteger(forKey: "totalTrainingSamples")

        super.init()
        
        updateFlowDimensions()
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(1, forKey: "fileVersion")
        aCoder.encode(inputDimensions, forKey: "inputDimensions")
        aCoder.encode(outputDimensions, forKey: "outputDimensions")
        
        aCoder.encode(splitChannelsIntoFlows, forKey: "splitChannelsIntoFlows")
        
        aCoder.encode(trainingDataInputSource.rawValue, forKey: "trainingDataInputSource")
        aCoder.encode(trainingInputDataURL, forKey: "trainingInputDataURL")
        aCoder.encode(separateTestingSource, forKey: "separateTestingSource")
        aCoder.encode(testingInputDataURL, forKey: "testingInputDataURL")
        
        aCoder.encode(inputFormat.rawValue, forKey: "inputFormat")
        aCoder.encode(inputDataParser, forKey: "inputDataParser")
        
        aCoder.encode(separateOutputSource, forKey: "separateOutputSource")
        aCoder.encode(trainingDataOutputSource.rawValue, forKey: "trainingDataOutputSource")
        aCoder.encode(trainingOutputDataURL, forKey: "trainingOutputDataURL")
        aCoder.encode(testingOutputDataURL, forKey: "testingOutputDataURL")
        
        aCoder.encode(outputFormat.rawValue, forKey: "outputFormat")
        aCoder.encode(outputDataParser, forKey: "outputDataParser")

        aCoder.encode(separateLabelFile, forKey: "separateLabelFile")
        aCoder.encode(labelFileURL, forKey: "labelFileURL")
        
        aCoder.encode(createTestDataFromTrainingData, forKey: "createTestDataFromTrainingData")
        aCoder.encode(testDataPercentage, forKey: "testDataPercentage")
        aCoder.encode(testDataSourceLocation.rawValue, forKey: "testDataSourceLocation")

        aCoder.encode(flows, forKey: "flows")
        aCoder.encode(outputFlow, forKey: "outputFlow")
        
        aCoder.encode(outputType.rawValue, forKey: "outputType")
        aCoder.encode(lossType.rawValue, forKey: "lossType")
        aCoder.encode(needsWeightInitialization, forKey: "needsWeightInitialization")
        aCoder.encode(batchSize, forKey: "batchSize")
        aCoder.encode(batchIndicesSource.rawValue, forKey: "batchIndicesSource")

        aCoder.encode(numEpochs, forKey: "numEpochs")
        aCoder.encode(testAfterEpoch, forKey: "testAfterEpoch")
        aCoder.encode(epochsBetweenTests, forKey: "epochsBetweenTests")
        aCoder.encode(useSubsetForTest, forKey: "useSubsetForTest")
        aCoder.encode(testSubsetSize, forKey: "testSubsetSize")
        aCoder.encode(learningRate, forKey: "learningRate")
        aCoder.encode(totalTrainingSamples, forKey: "totalTrainingSamples")
    }
}

// MARK: - Document class

class Document: NSDocument {
    //  Document data
    var docData : DocumentData
    var validNetwork = false
    
    //  Training data
    var trainingData : TrainingData?
 
    var lastLossNode : MPSNNFilterNode?
    var lastForwardNodeImage : MPSNNImageNode?      //  Last forward image in a forward/backward graph
    var inputImages : [MPSNNImageNode] = []

    override init() {
        docData = DocumentData()

        super.init()
        
        //  Validate the network
        validateNetwork()
    }
    
    func setInputDimension(index: Int, newDimension: Int)
    {
        if (index < 0 || index > 4) {return}
        docData.inputDimensions[index] = newDimension
        docData.needsWeightInitialization = true
        
        //  Update the flow sizes
        docData.updateFlowDimensions()
    }
    
    func setOutputDimension(index: Int, newDimension: Int)
    {
        if (index < 0 || index > 4) {return}
        docData.outputDimensions[index] = newDimension
    }

    func addLayer(toFlow : Int, newLayer: Layer)
    {
        if (toFlow < 0 || toFlow >= docData.flows.count) { return }
        docData.flows[toFlow].layers.append(newLayer)
        docData.needsWeightInitialization = true
        
        //  Update the flow sizes
        docData.updateFlowDimensions()
    }

    func insertLayer(inFlow : Int, newLayer: Layer, atIndex: Int)
    {
        if (inFlow < 0 || inFlow >= docData.flows.count) { return }
        docData.flows[inFlow].layers.insert(newLayer, at: atIndex)
        docData.needsWeightInitialization = true
        
        //  Update the flow sizes
        docData.updateFlowDimensions()
    }
    
    func updateLayer(inFlow : Int, fromLayer: Layer, atIndex: Int)
    {
        if (inFlow < 0 || inFlow >= docData.flows.count) { return }
        docData.flows[inFlow].layers[atIndex].setFrom(layer: fromLayer)
        docData.needsWeightInitialization = true
        
        //  Update the flow sizes
        docData.updateFlowDimensions()
    }
    
    func resetLayerSelection()
    {
        for flow in docData.flows {
            for layer in flow.layers { layer.selected = false }
        }
    }

    var outputType : OutputType
    {
        get { return docData.outputType}
        set { docData.outputType = newValue}
    }
    
    func getInputDimensionForFlowAndLayer(flowIndex: Int, layerIndex: Int) -> [Int]
    {
        if (flowIndex < 0 || flowIndex >= docData.flows.count) { return [-1,  -1, -1, -1]}
        let layerCount = docData.flows[flowIndex].layers.count
        if (layerIndex < 0 || layerIndex >= layerCount) { return [-1,  -1, -1, -1]}

        var dimensions = docData.flows[flowIndex].currentInputSize
        if (layerIndex == 0) { return dimensions }
        
        for i in 0..<layerIndex {
            dimensions = docData.flows[flowIndex].layers[i].getOutputDimensionGivenInput(dimensions: dimensions)
        }
        
        return dimensions
    }
    
    func getOutputDimensionForFlowAndLayer(flowIndex: Int, layerIndex: Int) -> [Int]
    {
        if (flowIndex < 0 || flowIndex >= docData.flows.count) { return [-1,  -1, -1, -1]}
        let layerCount = docData.flows[flowIndex].layers.count
        if (layerIndex < 0 || layerIndex >= layerCount) { return [-1,  -1, -1, -1]}
        
        var dimensions = docData.flows[flowIndex].currentInputSize
        
        for i in 0...layerIndex {
            dimensions = docData.flows[flowIndex].layers[i].getOutputDimensionGivenInput(dimensions: dimensions)
        }
        
        return dimensions
    }

    func getTypeStringForFlowAndLayer(flowIndex: Int, layerIndex: Int) -> String
    {
        if (flowIndex < 0 || flowIndex >= docData.flows.count) { return "Invalid Flow"}
        return docData.flows[flowIndex].layers[layerIndex].type.typeString + " - " + docData.flows[flowIndex].layers[layerIndex].subTypeString()
    }
    
    func getParameterStringForFlowAndLayer(flowIndex: Int, layerIndex: Int) -> String
    {
        if (flowIndex < 0 || flowIndex >= docData.flows.count) { return "Invalid Flow"}
        return docData.flows[flowIndex].layers[layerIndex].getParameterString()
    }

    func unsplitFlows()
    {
        //  Remove all flows except the one marked as the output
        let savedFlow = docData.flows[docData.outputFlow]
        docData.flows.removeAll()
        docData.flows.append(savedFlow)
        
        //  Change the output flow
        docData.outputFlow = 0
        
        //  Change the flow inputs to be the single input
        docData.flows[0].inputs.removeAll()
        docData.flows[0].inputs.append(InputSource(type: .Input, index: 0))
    }
    
    func splitFlows()
    {
        //  Get the number of flows we are going to split the input into
        let numFlows = docData.inputDimensions[2] * docData.inputDimensions[3]
        
        //  Insert each of the input flows before the current single flow
        for flowIndex in 0..<numFlows {
            let flow = Flow()
            flow.inputs.append(InputSource(type: .Input, index: flowIndex))
            docData.flows.insert(flow, at: flowIndex)
        }
        
        //  Make the last flow use the combined inputs
        let lastFlowIndex = docData.flows.count - 1;
        docData.flows[lastFlowIndex].inputs.removeAll()
        for flowIndex in 0..<numFlows {
            docData.flows[lastFlowIndex].inputs.append(InputSource(type: .Flow, index: flowIndex))
        }
        
        //  Make the last flow the final output
        docData.outputFlow = lastFlowIndex
    }
    
    @discardableResult
    func validateNetwork() -> String
    {
        validNetwork = false
        //  Check the input size compatibility for each flow
        let numFlows = docData.flows.count
        for flowIndex in 0..<numFlows {
            if (docData.flows[flowIndex].inputs.count > 1) {
                //  Get dimensions of first input
                var inputDimensions : [Int]
                let input = docData.flows[flowIndex].inputs[0]
                if (input.type == .Input) {
                    inputDimensions = docData.inputDimensions
                    if (docData.splitChannelsIntoFlows) {
                        inputDimensions[2] = 1
                        inputDimensions[3] = 1
                    }
                }
                else {
                    inputDimensions = docData.flows[input.index].currentOutputSize
                }
                
                //  Check all other inputs against it
                for inputIndex in 1..<docData.flows[flowIndex].inputs.count {
                    //  Get dimensions of this input
                    var dimensions : [Int]
                    let input = docData.flows[flowIndex].inputs[inputIndex]
                    if (input.type == .Input) {
                        dimensions = docData.inputDimensions
                        if (docData.splitChannelsIntoFlows) {
                            dimensions[2] = 1
                            dimensions[3] = 1
                        }
                    }
                    else {
                        dimensions = docData.flows[input.index].currentOutputSize
                    }
                    
                    //  Verify this input dimension matches
                    if (dimensions[0] != inputDimensions[0]) {
                        return "Flow \(flowIndex) has inputs with differing widths"
                    }
                    if (dimensions[1] != inputDimensions[1]) {
                        return "Flow \(flowIndex) has inputs with differing heights"
                    }
                }
            }
        }
        
        //  Check the output flow dimensions match the output dimensions
        var dimensionsMatch = true
        let dimensions = docData.getFlowOutputDimensions(flowIndex: docData.outputFlow)
        for i in 0..<4 {
            if (dimensions[i] != docData.outputDimensions[i]) { dimensionsMatch = false }
        }
        if (!dimensionsMatch) {
            return "Final dimensions of flow \(docData.outputFlow) " + NetworkViewController.dimensionsToString(dimensions: dimensions) +
                        " do not match output dimensions " + NetworkViewController.dimensionsToString(dimensions: docData.outputDimensions)
        }
        
        validNetwork = true
        return "Valid"
    }
    
    func initializeWeights()
    {
        //  Check each layer
        var dimensions = docData.inputDimensions
        
        for flow in docData.flows {
            for layer in flow.layers {
                layer.initializeWeights(inputDimensions: dimensions)
                dimensions = layer.getOutputDimensionGivenInput(dimensions: dimensions)
            }
        }
        
        docData.needsWeightInitialization = false
        docData.totalTrainingSamples = 0
    }
    
    func loadTrainingData()
    {
        docData.loadError = nil
        if (trainingData == nil) {
            docData.stopLoading.state = false
            trainingData = TrainingData(docData : docData)
            DispatchQueue.main.async {
                if (self.trainingData == nil) {
                    self.docData.loadingStatus = "Error loading data"
                }
                else {
                    self.docData.loadingStatus = "Data load complete"
                }
            }
        }
    }
    
    func abortLoading()
    {
        docData.stopLoading.state = true
    }
    
    var numTrainingSamples : Int
    {
        get {
            if (trainingData == nil) { return 0 }
            return trainingData!.trainingData.count
        }
    }
    
    var numTestingSamples : Int
    {
        get {
            if (trainingData == nil) { return 0 }
            return trainingData!.testingData.count
        }
    }

    func getTrainingSample(sampleNumber : Int) -> (input:[Float], output:[Float], outputClass: Int)?
    {
        return trainingData?.getTrainingSample(sampleNumber: sampleNumber)
    }

    func getTestingSample(sampleNumber : Int) -> (input:[Float], output:[Float], outputClass: Int)?
    {
        return trainingData?.getTestingSample(sampleNumber: sampleNumber)
    }

    override class var autosavesInPlace: Bool {
        return true
    }
    
    func getForwardGraph(commandQueue: MTLCommandQueue) -> MPSNNGraph?
    {
        //  Start with the placeholder input image for each input set
        inputImages = []
        if (docData.splitChannelsIntoFlows) {
            let numInputs = docData.inputDimensions[2] * docData.inputDimensions[3]
            for _ in 0..<numInputs {
                inputImages.append(MPSNNImageNode(handle: nil))
            }
        }
        else {
            inputImages.append(MPSNNImageNode(handle: nil))
        }
        
        //  Keep track of outputs of flows we have added
        let flowCount = docData.flows.count
        var flowOutputImages = [MPSNNImageNode?](repeating: nil, count: flowCount)
        
        //  Start with flows that only have inputs from data inputs
        for index in 0..<flowCount {
            let flow = docData.flows[index]
            if (flow.usesOnlyDataInput) {
                if let outputImage = flow.getGraphOutputImage(inputImages : inputImages, flowOutputImages : flowOutputImages, docData : docData) {
                    flowOutputImages[index] = outputImage
                }
                else {
                    return nil
                }
            }
        }

        //  Then iterate through the rest of the flows
        var somethingChanged = true
        while (somethingChanged) {
            somethingChanged = false
            for index in 0..<flowCount {
                let flow = docData.flows[index]
                if (flowOutputImages[index] == nil) {
                    if let outputImage = flow.getGraphOutputImage(inputImages : inputImages, flowOutputImages : flowOutputImages, docData : docData) {
                        flowOutputImages[index] = outputImage
                        somethingChanged = true
                    }
                }
            }
        }
        
        //  Validate that all the flows have output images
        for outputImage in flowOutputImages {
            if (outputImage == nil) { return nil }
        }

        //  Create the graph from the output flow's output image
        let graph = MPSNNGraph(device: commandQueue.device,
                                  resultImage: flowOutputImages[docData.outputFlow]!, resultImageIsNeeded: true)
        return graph
    }
    
    func getFullForwardBackwardGraph(commandQueue: MTLCommandQueue) -> MPSNNGraph?
    {
         //  Start with the placeholder input image for each input set
        inputImages = []
        if (docData.splitChannelsIntoFlows) {
            let numInputs = docData.inputDimensions[2] * docData.inputDimensions[3]
            for _ in 0..<numInputs {
                inputImages.append(MPSNNImageNode(handle: nil))
            }
        }
        else {
            inputImages.append(MPSNNImageNode(handle: nil))
        }
        
        //  Keep track of outputs of flows we have added
        let flowCount = docData.flows.count
        var flowOutputImages = [MPSNNImageNode?](repeating: nil, count: flowCount)
        
        //  Start with flows that only have inputs from data inputs
        for index in 0..<flowCount {
            let flow = docData.flows[index]
            if (flow.usesOnlyDataInput) {
                if let outputImage = flow.getGraphOutputImage(inputImages : inputImages, flowOutputImages : flowOutputImages, docData : docData) {
                    flowOutputImages[index] = outputImage
                }
                else {
                    return nil
                }
            }
        }
        
        //  Then iterate through the rest of the flows
        var somethingChanged = true
        while (somethingChanged) {
            somethingChanged = false
            for index in 0..<flowCount {
                let flow = docData.flows[index]
                if (flowOutputImages[index] == nil) {
                    if let outputImage = flow.getGraphOutputImage(inputImages : inputImages, flowOutputImages : flowOutputImages, docData : docData) {
                        flowOutputImages[index] = outputImage
                        somethingChanged = true
                    }
                }
            }
        }
        
        //  Validate that all the flows have output images
        for outputImage in flowOutputImages {
            if (outputImage == nil) { return nil }
        }
        
        //  Remember the last forward node for use in testing
        lastForwardNodeImage = flowOutputImages[docData.outputFlow]
        
        //  Add the loss layer
        let lossDescriptor = MPSCNNLossDescriptor(type: docData.lossType, reductionType: .none)        //!!
        if (docData.lossType == .softMaxCrossEntropy) {
            lossDescriptor.numberOfClasses = docData.outputDimensions.reduce(1, *)
        }
        let lossNode = MPSCNNLossNode(source: lastForwardNodeImage!, lossDescriptor: lossDescriptor)
        lastLossNode = lossNode        //  Keep a reference to the node so it isn't removed by memory management
        
        //  Start with the output flow and work backwards - this assumes each flow feeds into only one flow
        var lastInputImage = lossNode.resultImage
        var remainingFlows : [(flowIndex : Int, gradientSource: MPSNNImageNode)] = [(flowIndex : docData.outputFlow, gradientSource : lossNode.resultImage)]
        while (remainingFlows.count > 0) {
            //  Get the first flow queued up
            let flow = docData.flows[remainingFlows[0].flowIndex]

            //  Backtrack the gradient to the inputs
            let inputGradientImages = flow.getInputGradientImages(remainingFlows[0].gradientSource)
            remainingFlows.removeFirst()

            //  Add any input flows to the queue
            for index in 0..<flow.inputs.count {
                if (flow.inputs[index].type == .Flow) {
                    remainingFlows.append((flowIndex : flow.inputs[index].index, gradientSource : inputGradientImages[index]))
                }
                else {
                    //  Remember input images - last one gets added to the graph
                    lastInputImage = inputGradientImages[index]
                }
            }
        }

        let graph = MPSNNGraph(device: commandQueue.device,
                               resultImage: lastInputImage, resultImageIsNeeded: false)
        
        //  Set the weight/bias state for trainable nodes
        setWeightAndBiasStates(device: commandQueue.device)
        
        return graph
    }
    
    func getForwardHalfOfFullGraph(commandQueue: MTLCommandQueue) -> MPSNNGraph?
    {
        if (lastForwardNodeImage == nil) { return nil }
        let graph = MPSNNGraph(device: commandQueue.device,
                               resultImage: lastForwardNodeImage!, resultImageIsNeeded: true)
        return graph
    }
    
    func setWeightAndBiasStates(device: MTLDevice)
    {
        for flow in docData.flows {
            flow.setWeightAndBiasStates(device: device)
        }
    }

    func setMainLearningRate()
    {
        for flow in docData.flows {
            for layer in flow.layers {
                layer.setMainLearningRate(docData.learningRate)
            }
        }
    }

    override func makeWindowControllers() {
        // Returns the Storyboard that contains your Document window.
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let windowController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("Document Window Controller")) as! NSWindowController
        self.addWindowController(windowController)
    }

    override func data(ofType typeName: String) throws -> Data {
        // Insert code here to write your document to data of the specified type, throwing an error in case of failure.
        guard let archive: Data = try? NSKeyedArchiver.archivedData(withRootObject: docData, requiringSecureCoding: false)
            else
        {
            let outError:NSError! = NSError(domain: NSOSStatusErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey : "Error archiving document"])
            throw outError
        }
        return archive
    }

    override func read(from data: Data, ofType typeName: String) throws {
        // Insert code here to read your document from the given data of the specified type, throwing an error in case of failure.

        guard let archive = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as! DocumentData?
            else
        {
            let outError: NSError! = NSError(domain: NSOSStatusErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey : "The document could not be unarchived"])
            throw outError
        }
        
        docData = archive
        validateNetwork()
    }


}

