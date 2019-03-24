//
//  Padding.swift
//  SwiftNNTrainer
//
//  Created by Kevin Coble on 2/22/19.
//  Copyright © 2019 Kevin Coble. All rights reserved.
//

import Foundation
import MetalPerformanceShaders
import MetalKit

class Padding : NSObject, MPSNNPadding
{
    var layer : Layer?   //  Layer associated with this padding
    
    override init() {
        super.init()
    }
    
    static var supportsSecureCoding: Bool = true
    
    required init?(coder aDecoder: NSCoder) {
        super.init()
    }
    
    func encode(with aCoder: NSCoder) {
        // nothing to do here
    }
    
    func paddingMethod() -> MPSNNPaddingMethod {
        return [ layer!.XPaddingMethod.padVar, layer!.YPaddingMethod.padVar, layer!.featurePaddingMethod.padVar ]
    }
    
    func destinationImageDescriptor(forSourceImages sourceImages: [MPSImage],
                                    sourceStates: [MPSState]?,
                                    for kernel: MPSKernel,
                                    suggestedDescriptor inDescriptor: MPSImageDescriptor) -> MPSImageDescriptor {
//        if let kernel = kernel as? MPSCNNPooling {
//            kernel.offset = MPSOffset(x: 1, y: 1, z: 0)
//            kernel.edgeMode = .clamp
//        }
        return inDescriptor
    }
    
    func label() -> String {
        return "Padding"
    }
}
