//
//  Flow.swift
//  SwiftNNTrainer
//
//  Created by Kevin Coble on 3/3/19.
//  Copyright © 2019 Kevin Coble. All rights reserved.
//

import Cocoa
import MetalPerformanceShaders
import MetalKit

enum InputType : Int {
    case Input = 1
    case Flow = 2
}

struct InputSource {
    let type : InputType
    let index : Int
    
    func idString() -> String
    {
        switch (type) {
        case .Input:
            return "Input \(index)"
        case .Flow:
            return "Flow \(index)"
        }
    }
}

// MARK: - Flow

class Flow : NSObject, NSCoding
{
    var inputs : [InputSource]

    var lastConcatenationNode : MPSNNConcatenationNode?
    var lastContractionNode : MPSCNNConvolutionNode?
    var lastConcatenationGradientNode : MPSNNGradientFilterNode?
    var lastContractionGradientNode : MPSNNGradientFilterNode?

    //  Current network layers
    var layers : [Layer]
    
    //  Display information
    var currentInputSize = [-1, -1, -1, -1]
    var currentOutputSize = [-1, -1, -1, -1]

    override init() {
        inputs = []
        
        layers = []
    }
    
    var usesOnlyDataInput : Bool {
        get {
            var foundFlow = false
            
            for input in inputs {
                if (input.type == .Flow) {foundFlow = true}
            }
            
            return !foundFlow
        }
    }

    func inputSourceString() -> String
    {
        var string = ""
        
        for input in inputs {
            if (string.count > 0) { string += ", "}
            string += input.idString()
        }
        
        return string
    }
    
    @discardableResult
    func updateDimensionsFromData(_ docData: DocumentData) -> Bool
    {
        var changed = false
        
        //  Get new input dimensions
        var newInputDimensions = [-1, -1, -1, -1]
        for input in inputs {
            if (input.type == .Input) {
                //  Get the data input dimensions
                var dataInputDimensions = docData.inputDimensions
                if (docData.splitChannelsIntoFlows) {
                    dataInputDimensions[2] = 1
                    dataInputDimensions[3] = 1
                }
                
                //  If this is the first input, set it
                if (newInputDimensions[0] < 0) {
                    newInputDimensions = dataInputDimensions
                }
                    
                //  Otherwise, add the channels (ignore size for now - that is checked in network validity)
                else {
                    newInputDimensions[2] += dataInputDimensions[2] * dataInputDimensions[3]
                }
            }
            else {
                //  Get the flow output dimensions
                if (input.index >= docData.flows.count) { return false }
                let flowOutputDimensions = docData.flows[input.index].currentInputSize
                if (flowOutputDimensions[0] < 0) { return false }
                
                //  If this is the first input, set it
                if (newInputDimensions[0] < 0) {
                    newInputDimensions = flowOutputDimensions
                }
                    
                //  Otherwise, add the channels (ignore size for now - that is checked in network validity)
                else {
                    newInputDimensions[2] += flowOutputDimensions[2] * flowOutputDimensions[3]
                }
            }
        }
        if (newInputDimensions[0] < 0) { return false }
        
        //  See if they changed
        for i in 0..<4 { if (newInputDimensions[i] != currentInputSize[i]) { changed = true }}
        currentInputSize = newInputDimensions
        
        //  Get the output dimensions
        var dimensions = currentInputSize
        for layer in layers {
            dimensions = layer.getOutputDimensionGivenInput(dimensions: dimensions)
        }
        
        //  See if the output dimensions changed
        for i in 0..<4 { if (currentOutputSize[i] != dimensions[i]) { changed = true }}
        currentOutputSize = dimensions
        
        return changed
    }
    
    func getGraphOutputImage(inputImages : [MPSNNImageNode], flowOutputImages: [MPSNNImageNode?], docData : DocumentData) -> MPSNNImageNode?
    {
        //  If more than one input, add a concatenation node
        var currentInputImage : MPSNNImageNode
        if (inputs.count < 1) { return nil }
        if (inputs.count > 1) {
            var concatenationInputs : [MPSNNImageNode] = []
            var inputChannelSizes : [Int] = []
            for input in inputs {
                if (input.type == .Input) {
                    concatenationInputs.append(inputImages[input.index])
                    inputChannelSizes.append(1)
                }
                else {
                    if let flowOutput = flowOutputImages[input.index] {
                        concatenationInputs.append(flowOutput)
                        let channels = docData.flows[input.index].currentInputSize[2] * docData.flows[input.index].currentInputSize[3]
                        inputChannelSizes.append(channels)
                    }
                    else {
                        return nil
                    }
                }
            }
            lastConcatenationNode = MPSNNConcatenationNode(sources: concatenationInputs)
            
            //  Create the contraction node
            let contractionWeights = ConcatenationContractionWeights(inputChannelSizes : inputChannelSizes)
            let contractionPadding = ConcatenationContractionPadding()
            lastContractionNode = MPSCNNConvolutionNode(source: lastConcatenationNode!.resultImage, weights: contractionWeights)
            lastContractionNode!.paddingPolicy = contractionPadding
            
            //  Continue with the flow after the concatenation
            currentInputImage = lastContractionNode!.resultImage
        }
            
            //  Only one input, get it
        else {
            if (inputs[0].type == .Input) {
                currentInputImage = inputImages[inputs[0].index]
            }
            else {
                if (flowOutputImages[inputs[0].index] == nil) { return nil }
                currentInputImage = flowOutputImages[inputs[0].index]!
            }
        }
        
        //  Add each layer
        for layer in layers {
            currentInputImage = layer.getNode(inputImage: currentInputImage)
        }

        return currentInputImage
    }
    
    func getInputGradientImages(_ startingImage : MPSNNImageNode) -> [MPSNNImageNode]
    {
        //  Work backwards through the layers, getting the gradient node
        var currentImage = startingImage
        for layer in layers.reversed() {
            currentImage = layer.getGradientNode(inputImage: currentImage)
        }
        
        //  If only one input, return that
        if (inputs.count == 1) {
            return [currentImage]
        }
        
        //  Work backwards through the compaction layer
        lastContractionGradientNode = lastContractionNode?.gradientFilter(withSource: currentImage)
        currentImage = lastContractionGradientNode!.resultImage
        
        //  Work backwards through the concatenation layer
        if let gradientFilters = lastConcatenationNode?.gradientFilters(withSource: currentImage) {
            var returnImages : [MPSNNImageNode] = []
            for filter in gradientFilters {
                returnImages.append(filter.resultImage)
            }
            return returnImages
        }
        return []
    }
    
    func setWeightAndBiasStates(device: MTLDevice)
    {
        for layer in layers {
            layer.setWeightAndBiasState(device: device)
        }
    }

    // MARK: NSCoding
    
    required init?(coder aDecoder: NSCoder) {
        let version = aDecoder.decodeInteger(forKey: "fileVersion")
        if (version > 1) { return nil }
        
        //  Decode the input sources
        inputs = []
        let numInputs = aDecoder.decodeInteger(forKey: "numInputs")
        for index in 0..<numInputs {
            let type = InputType(rawValue: aDecoder.decodeInteger(forKey: "input_type_\(index)"))!
            let inputIndex = aDecoder.decodeInteger(forKey: "input_index_\(index)")
            let input = InputSource(type: type, index: inputIndex)
            inputs.append(input)
        }
        
        //  Decode the layers
        layers = aDecoder.decodeObject(forKey: "layers") as! [Layer]
        
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(1, forKey: "fileVersion")
        
        //  Write the input sources
        aCoder.encode(inputs.count, forKey: "numInputs")
        for index in 0..<inputs.count {
            aCoder.encode(inputs[index].type.rawValue, forKey: "input_type_\(index)")
            aCoder.encode(inputs[index].index, forKey: "input_index_\(index)")
        }
        
        //  Write the layers
        aCoder.encode(layers, forKey: "layers")
    }
}
