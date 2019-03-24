//
//  MPSImageExtensions.swift
//  SwiftNNTrainer
//
//  Created by Kevin Coble on 2/27/19.
//  Copyright © 2019 Kevin Coble. All rights reserved.
//

import Foundation
import MetalPerformanceShaders

extension MPSImage {
    public func getResultArray() -> [Float]
    {
        //  Get the data from the image
        let directValue = toFloatArray()
        
        //  Allocate an array based on the image size
        let count = width * height * featureChannels
        var finalValues = [Float](repeating: 0.0, count: count)
        
        //  Transfer the values
        let numSlices = (featureChannels + 3)/4
        let channelsPerSlice = (featureChannels < 3) ? featureChannels : 4
        var index = 0
        var finalIndex : Int
        let featureSize = width * height
        for slice in 0..<numSlices {
            for y in 0..<height {
                var rowIndex = y * width
                for _ in 0..<width {
                    for channel in 0..<channelsPerSlice {
                        let feature = slice * channelsPerSlice + channel
                        if (feature < featureChannels) {
                            finalIndex = featureSize * feature + rowIndex
                            finalValues[finalIndex] = directValue[index]
                        }
                        index += 1
                    }
                    rowIndex += 1
                }
            }
        }
        
        //  Return the translated array
        return finalValues
    }
}
