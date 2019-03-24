//
//  ConcatenationContraction.swift
//  SwiftNNTrainer
//
//  Created by Kevin Coble on 3/3/19.
//  Copyright © 2019 Kevin Coble. All rights reserved.
//

import Cocoa
import MetalPerformanceShaders
import MetalKit

class ConcatenationContractionWeights : NSObject, NSCoding, MPSCNNConvolutionDataSource
{
    let inputChannels : Int
    let outputChannels: Int
    let inputChannelSizes : [Int]
    
    init(inputChannelSizes : [Int])
    {
        var total = 0
        for inputSize in inputChannelSizes {
            total += inputSize
            let remainder = (inputSize % 4)
            if (remainder > 0) { total += 4 - remainder }
        }
        inputChannels = total
        outputChannels = inputChannelSizes.reduce(0, +)
        self.inputChannelSizes = inputChannelSizes
    }
    
    // MARK: NSCoding
    
    required init?(coder aDecoder: NSCoder) {
        inputChannels = 1
        outputChannels = 1
        inputChannelSizes = []
        //  Nothing to read
    }
    
    func encode(with aCoder: NSCoder) {
        //  Nothing to write
    }
    
    //  MARK: NSCopying
    func copy(with zone: NSZone? = nil) -> Any {
        fatalError("copyWithZone not implemented")
    }
    
    
    //  MARK: MPSCNNConvolutionDataSource
    func dataType() -> MPSDataType {
        return .float32
    }
    
    func descriptor() -> MPSCNNConvolutionDescriptor {
        let desc = MPSCNNConvolutionDescriptor(kernelWidth: 1,
                                               kernelHeight: 1,
                                               inputFeatureChannels: inputChannels,
                                               outputFeatureChannels: outputChannels)
        return desc
    }
    
    func weights() -> UnsafeMutableRawPointer {
        var weightArray = [Float](repeatElement(0.0, count: inputChannels * outputChannels))
        
        //  Get the input location of each outputchannel
        var location : [Int] = []
        var inputFeature = 0
        for featuresInInput in inputChannelSizes {
            for _ in 0..<featuresInInput {
                location.append(inputFeature)
                inputFeature += 1
            }
            let remainder = (featuresInInput % 4)
            if (remainder != 0) { inputFeature += 4 - remainder }
        }

        //  Fill in the weight array
        for output in 0..<outputChannels {
            let index = output * inputChannels + location[output]
            weightArray[index] = 1.0
        }
 
        return UnsafeMutableRawPointer(mutating: weightArray)
    }
    
    func biasTerms() -> UnsafeMutablePointer<Float>? {
        return nil
    }
    
    func load() -> Bool {
        return true
    }
    
    func purge() {
        //  Nothing to do here
    }
    
    func label() -> String? {
        return "Concatenation Contraction"
    }

}


class ConcatenationContractionPadding : NSObject, MPSNNPadding
{
    override init()
    {
    }
    
    // MARK: MPSNNPadding
    
    func paddingMethod() -> MPSNNPaddingMethod {
        return [ .validOnly, .validOnly, .validOnly ]
    }
    
    // MARK: NSCoding
    
    required init?(coder aDecoder: NSCoder) {
        //  Nothing to read
    }
    
    func encode(with aCoder: NSCoder) {
        //  Nothing to write
    }
    
    //  MARK: NSCopying
    func copy(with zone: NSZone? = nil) -> Any {
        fatalError("copyWithZone not implemented")
    }

    // MARK: NSSecureCoding
    static var supportsSecureCoding: Bool = true
}
