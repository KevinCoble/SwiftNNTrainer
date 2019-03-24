//
//  LayerEnums.swift
//  SwiftNNTrainer
//
//  Created by Kevin Coble on 2/22/19.
//  Copyright © 2019 Kevin Coble. All rights reserved.
//

import Cocoa
import MetalPerformanceShaders
import MetalKit

enum LayerType : Int {
    case Arithmetic = 1
    case Convolution = 2
    case Pooling = 3
    case FullyConnected = 4
    case Neuron = 5
    case SoftMax = 6
    case Normalization = 7
    case UpSampling = 8
    case DropOut = 9
    
    var typeString : String
    {
        get {
            switch (self)
            {
            case .Arithmetic:
                return "Arithmetic"
            case .Convolution:
                return "Convolution"
            case .Pooling:
                return "Pooling"
            case .FullyConnected:
                return "Fully Connected"
            case .Neuron:
                return "Neuron"
            case .SoftMax:
                return "SoftMax"
            case .Normalization:
                return "Normalization"
            case .UpSampling:
                return "Up Sampling"
            case .DropOut:
                return "Drop Out"
            }
        }
    }
}

enum ConvolutionSubType : Int
{
    case Normal = 1
    case Binary = 2
    case Transpose = 3
    
    var subTypeString : String
    {
        get {
            switch (self)
            {
            case .Normal:
                return "Normal"
            case .Binary:
                return "Binary"
            case .Transpose:
                return "Transpose"
            }
        }
    }
}

enum PoolingSubType : Int
{
    case Average = 1
    case L2Norm = 2
    case Max = 3
    case DilatedMax = 4
    
    var subTypeString : String
    {
        get {
            switch (self)
            {
            case .Average:
                return "Average"
            case .L2Norm:
                return "L2 Norm"
            case .Max:
                return "Maximum"
            case .DilatedMax:
                return "Dilated Maximum"
            }
        }
    }
}

enum FullyConnectedSubType : Int {
    case NormalWeights = 1
    case BinaryWeights = 2
    
    var subTypeString : String
    {
        get {
            switch (self)
            {
            case .NormalWeights:
                return "Normal Weights"
            case .BinaryWeights:
                return "Binary Weights"
            }
        }
    }
}

enum NeuronSubType : Int {
    case Absolute = 1
    case ELU = 2
    case HardSigmoid = 3
    case Linear = 4
    case PReLU = 5
    case ReLUN = 6
    case ReLU = 7
    case Sigmoid = 8
    case SoftPlus = 9
    case SoftSign = 10
    case TanH = 11
    case Exponential = 12
    case Logarithm = 13
    case Power = 14
    
    var subTypeString : String
    {
        get {
            switch (self)
            {
            case .Absolute:
                return "Absolute"
            case .ELU:
                return "ELU"
            case .HardSigmoid:
                return "Hard Sigmoid"
            case .Linear:
                return "Linear"
            case .PReLU:
                return "PReLU"
            case .ReLUN:
                return "ReLUN"
            case .ReLU:
                return "ReLU"
            case .Sigmoid:
                return "Sigmoid"
            case .SoftPlus:
                return "Soft Plus"
            case .SoftSign:
                return "Soft Sign"
            case .TanH:
                return "TanH"
            case .Exponential:
                return "Exponential"
            case .Logarithm:
                return "Logarithm"
            case .Power:
                return "Power"
            }
        }
    }
}

enum SoftMaxSubType : Int {
    case SoftMax = 1
    case LogSoftMax = 2
    
    var subTypeString : String
    {
        get {
            switch (self)
            {
            case .SoftMax:
                return "SoftMax"
            case .LogSoftMax:
                return "Logarithmic SoftMax"
            }
        }
    }
}

enum NormalizationSubType : Int {
    case CrossCannel = 1
    case LocalContrast = 2
    case Spatial = 3
    case Batch = 4
    case Instance = 5

    var subTypeString : String
    {
        get {
            switch (self)
            {
            case .CrossCannel:
                return "Cross Channel"
            case .LocalContrast:
                return "Local Contrast"
            case .Spatial:
                return "Spatial"
            case .Batch:
                return "Batch"
            case .Instance:
                return "Instance"
            }
        }
    }
}

enum UpSamplingSubType : Int {
    case BiLinear = 1
    case Nearest = 2
    
    var subTypeString : String
    {
        get {
            switch (self)
            {
            case .BiLinear:
                return "Bi-Linear"
            case .Nearest:
                return "Nearest"
            }
        }
    }
}

enum DropOutSubType : Int {
    case Standard = 1
    
    var subTypeString : String
    {
        get {
            switch (self)
            {
            case .Standard:
                return "Standard"
            }
        }
    }
}

enum PaddingMethod : Int {
    case ValidOnly = 0
    case SizeSame = 1
    case SizeFull = 2
    case Custom = 3
    
    var padVar : MPSNNPaddingMethod {
        get {
            switch (self)
            {
            case .ValidOnly:
                return MPSNNPaddingMethod.validOnly
            case .SizeSame:
                return MPSNNPaddingMethod.sizeSame
            case .SizeFull:
                return MPSNNPaddingMethod.sizeFull
            case .Custom:
                return MPSNNPaddingMethod.custom
            }
        }
    }
}

enum UpdateRule: Int {
    case SGD = 1
    case RMSProp = 2
    case Adam = 3
}


enum AdditionalDataType {
    case float
    case int
    case bool
}

struct AdditionalDataInfo {
    let type : AdditionalDataType
    let name : String
    let minimum : Float
    let maximum : Float
}
