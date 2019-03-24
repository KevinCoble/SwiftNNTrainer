//
//  NormalizationData.swift
//  SwiftNNTrainer
//
//  Created by Kevin Coble on 2/28/19.
//  Copyright © 2019 Kevin Coble. All rights reserved.
//

import Foundation
import MetalPerformanceShaders
import MetalKit


class BatchNormalizationData : NSObject, NSCoding, MPSCNNBatchNormalizationDataSource
{
    var layer : Layer?   //  Layer associated with this normalization data
    var betaArray : [Float]?
    var gammaArray : [Float]?
    var meanArray : [Float]?
    var varianceArray : [Float]?
    
    override init() {
        super.init()
    }

    func numberOfFeatureChannels() -> Int {
        if let layer = layer {
            return layer.inputChannels
        }
        return 0
    }
    
    func gamma() -> UnsafeMutablePointer<Float>? {
        //  If not created, create now
        if (layer == nil) { return nil }
        if (gammaArray == nil) {
            gammaArray = [Float](repeating: 0.0, count: layer!.inputChannels)
        }
        
        //  If too small an array, re-create
        if (gammaArray!.count < layer!.inputChannels) {
            gammaArray = [Float](repeating: 0.0, count: layer!.inputChannels)
        }
        
        return UnsafeMutablePointer(mutating: gammaArray!)
    }
    
    func beta() -> UnsafeMutablePointer<Float>? {
        //  If not created, create now
        if (layer == nil) { return nil }
        if (betaArray == nil) {
            betaArray = [Float](repeating: 0.0, count: layer!.inputChannels)
        }
        
        //  If too small an array, re-create
        if (betaArray!.count < layer!.inputChannels) {
            betaArray = [Float](repeating: 0.0, count: layer!.inputChannels)
        }
        
        return UnsafeMutablePointer(mutating: betaArray!)
    }
    
    func mean() -> UnsafeMutablePointer<Float>? {
        //  If not created, create now
        if (layer == nil) { return nil }
        if (meanArray == nil) {
            meanArray = [Float](repeating: 0.0, count: layer!.inputChannels)
        }
        
        //  If too small an array, re-create
        if (meanArray!.count < layer!.inputChannels) {
            meanArray = [Float](repeating: 0.0, count: layer!.inputChannels)
        }
        
        return UnsafeMutablePointer(mutating: meanArray!)
    }
    
    func variance() -> UnsafeMutablePointer<Float>? {
        //  If not created, create now
        if (layer == nil) { return nil }
        if (varianceArray == nil) {
            varianceArray = [Float](repeating: 0.0, count: layer!.inputChannels)
        }
        
        //  If too small an array, re-create
        if (varianceArray!.count < layer!.inputChannels) {
            varianceArray = [Float](repeating: 0.0, count: layer!.inputChannels)
        }
        
        return UnsafeMutablePointer(mutating: varianceArray!)
    }
    
    func load() -> Bool {
        //  No loading
        return true
    }
    
    func purge() {
        //  No purging
    }
    
    func label() -> String? {
        if let layer = layer {
            return layer.label()! + " Norm. Data"
        }
        return "Batch Normalization Data"
    }
    

    // MARK: - NSCoding
    required init?(coder aDecoder: NSCoder) {
        super.init()
    }
    
    func encode(with aCoder: NSCoder) {
        // nothing to do here
    }
    
    //  MARK: NSCopying
    func copy(with zone: NSZone? = nil) -> Any {
        fatalError("copyWithZone not implemented")
    }
}

class InstanceNormalizationData : NSObject, NSCoding, MPSCNNInstanceNormalizationDataSource
{
    var layer : Layer?   //  Layer associated with this normalization data
    var betaArray : [Float]?
    var gammaArray : [Float]?
    
    override init() {
        super.init()
    }

    // MARK: - NSCoding
    required init?(coder aDecoder: NSCoder) {
        super.init()
    }
    
    func encode(with aCoder: NSCoder) {
        // nothing to do here
    }
    
    //  MARK: NSCopying
    func copy(with zone: NSZone? = nil) -> Any {
        fatalError("copyWithZone not implemented")
    }

    //  MARK: - MPSCNNInstanceNormalizationDataSource
    var numberOfFeatureChannels: Int
    {
        get {
            if let layer = layer {
                return layer.inputChannels
            }
            return 0
        }
    }
    
    func beta() -> UnsafeMutablePointer<Float>?
    {
        //  If not created, create now
        if (layer == nil) { return nil }
        if (betaArray == nil) {
            betaArray = [Float](repeating: 0.0, count: layer!.inputChannels)
        }
        
        //  If too small an array, re-create
        if (betaArray!.count < layer!.inputChannels) {
            betaArray = [Float](repeating: 0.0, count: layer!.inputChannels)
        }
        
        return UnsafeMutablePointer(mutating: betaArray!)
    }
    
    func epsilon() -> Float
    {
        return 1.0
    }
    
    func gamma() -> UnsafeMutablePointer<Float>?
    {
        //  If not created, create now
        if (layer == nil) { return nil }
        if (gammaArray == nil) {
            gammaArray = [Float](repeating: 0.0, count: layer!.inputChannels)
        }
        
        //  If too small an array, re-create
        if (gammaArray!.count < layer!.inputChannels) {
            gammaArray = [Float](repeating: 0.0, count: layer!.inputChannels)
        }
        
        return UnsafeMutablePointer(mutating: gammaArray!)
    }
    
    func label() -> String? {
        if let layer = layer {
            return layer.label()! + " Norm. Data"
        }
        return "Instance Normalization Data"
    }
}
