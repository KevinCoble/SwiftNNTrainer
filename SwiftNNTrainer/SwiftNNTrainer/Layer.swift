//
//  Layer.swift
//  
//
//  Created by Kevin Coble on 2/6/19.
//

import Cocoa
import MetalPerformanceShaders
import MetalKit

class Layer : NSObject, NSCoding, MPSCNNConvolutionDataSource
{
    var type: LayerType
    var subType: Int
    var kernelWidth : Int
    var kernelHeight : Int
    var strideX : Int
    var strideY : Int
    var numChannels : Int       //  Neurons for fully-connected layers
    var useBiasTerms : Bool
    var weightArray : [Float]?
    var biases : [Float]?
    var inputChannels : Int
    var layerName: String?
    
    //  Padding information
    var XPaddingMethod : PaddingMethod
    var YPaddingMethod : PaddingMethod
    var featurePaddingMethod : PaddingMethod
    var XOffset : Int
    var YOffset : Int
    var featureOffset : Int
    var clipWidth : Int
    var clipHeight : Int
    var clipDepth : Int
    var edgeMode : MPSImageEdgeMode
    var paddingConstant : Float
    
    //  Update information
    var updateRule : UpdateRule
    var learningRateMultiplier : Float
    var momentumScale : Float
    var useNesterovMomentum : Bool
    var epsilon : Float
    var beta1 : Double      //  Used as decay for RMSProp
    var beta2 : Double
    var timeStep : Int
    var gradientRescale : Float
    var applyGradientClipping : Bool
    var gradientClipMax : Float
    var gradientClipMin : Float
    var regularizationType : MPSNNRegularizationType
    var regularizationScale : Float
    
    //  Additional data - see getAdditionalDataInfo for info for each subtype
    var additionalData : [Float]

    //  Run-time data
    var lastNode : MPSNNFilterNode?
    var lastGradientNode : MPSNNFilterNode?
    var updateOptimizer : MPSNNOptimizer?
    var weightsAndBiasState : MPSCNNConvolutionWeightsAndBiasesState?
    var currentLearningRate : Float = 0.01
    var inputMomentumVectors : [MPSVector]?
    var inputSumOfSquaresVectors : [MPSVector]?
    var inputVelocityVectors : [MPSVector]?
    
    var selected = false

    override init() {
        self.type = .FullyConnected
        self.subType = 1
        kernelWidth = 1
        kernelHeight = 1
        strideX = 1
        strideY = 1
        numChannels = 1
        useBiasTerms = false
        inputChannels = 1
        
        XPaddingMethod = .ValidOnly
        YPaddingMethod = .ValidOnly
        featurePaddingMethod = .ValidOnly
        XOffset = 0
        YOffset = 0
        featureOffset = 0
        clipWidth = 0
        clipHeight = 0
        clipDepth = 0
        edgeMode = .zero
        paddingConstant = 1.0
        
        updateRule = .SGD
        learningRateMultiplier = 1.0
        momentumScale = 0.0
        useNesterovMomentum  = false
        epsilon = 1e-08
        beta1 = 0.9      //  Used as decay for RMSProp
        beta2 = 0.999
        timeStep = 0
        gradientRescale = 1.0
        applyGradientClipping = false
        gradientClipMax = 1.0
        gradientClipMin = -1.0
        regularizationType = .None
        regularizationScale = 1.0

        additionalData = [Float](repeating: 0.0, count: 12)
        
        super.init()
        
        initializeAdditionalDataInfo()
    }

    func setFrom(layer: Layer)
    {
        var updateAdditionalInfo = false
        if (type != layer.type) {updateAdditionalInfo = true}
        type = layer.type
        if (subType != layer.subType) {updateAdditionalInfo = true}
        subType = layer.subType
        if (updateAdditionalInfo) {initializeAdditionalDataInfo()}
        kernelWidth = layer.kernelWidth
        kernelHeight = layer.kernelHeight
        strideX = layer.strideX
        strideY = layer.strideY
        numChannels = layer.numChannels
        useBiasTerms = layer.useBiasTerms
        weightArray = layer.weightArray
        biases = layer.biases
        inputChannels = layer.inputChannels
        layerName = layer.layerName
        
        XPaddingMethod = layer.XPaddingMethod
        YPaddingMethod = layer.YPaddingMethod
        featurePaddingMethod = layer.featurePaddingMethod
        XOffset = layer.XOffset
        YOffset = layer.YOffset
        featureOffset = layer.featureOffset
        clipWidth = layer.clipWidth
        clipHeight = layer.clipHeight
        clipDepth = layer.clipDepth
        edgeMode = layer.edgeMode
        paddingConstant = layer.paddingConstant
        
        updateRule = layer.updateRule
        learningRateMultiplier = layer.learningRateMultiplier
        momentumScale = layer.momentumScale
        useNesterovMomentum = layer.useNesterovMomentum
        epsilon = layer.epsilon
        beta1 = layer.beta1
        beta2 = layer.beta2
        timeStep = layer.timeStep
        gradientRescale = layer.gradientRescale
        applyGradientClipping = layer.applyGradientClipping
        gradientClipMax = layer.gradientClipMax
        gradientClipMin = layer.gradientClipMin
        regularizationType = layer.regularizationType
        regularizationScale = layer.regularizationScale

        additionalData = layer.additionalData
    }
    
    func getOutputDimensionGivenInput(dimensions: [Int]) -> [Int]
    {
        switch (type)
        {
        case .Arithmetic:
            return dimensions
            
        case .Convolution:
            //  Set the input channels
            inputChannels = dimensions[2] * dimensions[3]
            
            //  Determine the output size
            let xOutputSize = Layer.sizeGivenPadding(method : XPaddingMethod, sourceSize : dimensions[0], kernelSize : kernelWidth, stride: strideX, offset: XOffset, clip: clipWidth)
            let yOutputSize = Layer.sizeGivenPadding(method : YPaddingMethod, sourceSize : dimensions[1], kernelSize : kernelHeight, stride: strideY, offset: YOffset, clip: clipHeight)
            return [xOutputSize, yOutputSize, numChannels, dimensions[3]]

        case .Pooling:
            let xOutputSize = Layer.sizeGivenPadding(method : XPaddingMethod, sourceSize : dimensions[0], kernelSize : kernelWidth, stride: strideX, offset: XOffset, clip: clipWidth)
            let yOutputSize = Layer.sizeGivenPadding(method : YPaddingMethod, sourceSize : dimensions[1], kernelSize : kernelHeight, stride: strideY, offset: YOffset, clip: clipHeight)
            return [xOutputSize, yOutputSize, dimensions[2], dimensions[3]]

        case .FullyConnected:
            return [1, 1, numChannels, 1]
            
        case .Neuron, .SoftMax, .Normalization:
            return dimensions
            
        case .UpSampling:
            let scaleFactorX = Int(additionalData[0] + 0.1)
            let scaleFactorY = Int(additionalData[1] + 0.1)
            return [dimensions[0] * scaleFactorX, dimensions[1] * scaleFactorY, dimensions[2], dimensions[3]]
            
        case .DropOut:
            return dimensions

       }
    }
    
    func setSizeDependentParameters(_ dimensions: [Int])
    {
        //  Set the input channels for layers that have a weight descriptor
        inputChannels = dimensions[2] * dimensions[3]

        //  Only have to set kernel size for fully-connected layers
        if (type == .FullyConnected) {
            kernelWidth = dimensions[0]
            kernelHeight = dimensions[1]
        }
    }

    class func sizeGivenPadding(method : PaddingMethod, sourceSize : Int, kernelSize : Int, stride: Int, offset: Int, clip: Int) -> Int
    {
        switch (method) {
        case .ValidOnly:
            return (sourceSize - kernelSize) / stride + 1
        case .SizeSame:
            return (sourceSize - 1) / stride + 1
        case .SizeFull:
            return (sourceSize + kernelSize - 2) / stride + 1
        case .Custom:
            return (clip - offset) / stride
        }
    }
    
    func paddingDescription() -> String
    {
        //  We only have padding on pooling and convolutional layers
        if (type == .Convolution || type == .Pooling) {
            if (XPaddingMethod == .ValidOnly && YPaddingMethod == .ValidOnly && featurePaddingMethod == .ValidOnly) { return "None" }
            var desc = ""
            var previous = false
            if (XPaddingMethod != .ValidOnly) {
                desc = "X"
                previous = true
            }
            if (YPaddingMethod != .ValidOnly) {
                if (previous) { desc += ", " }
                desc += "Y"
                previous = true
            }
            if (featurePaddingMethod != .ValidOnly) {
                if (previous) { desc += ", " }
                desc += "features"
                previous = true
            }
            switch (edgeMode) {
            case .zero:
                desc += " padded with zero"
            case .clamp:
                desc += " padded by clamping"
            case .constant:
                if #available(OSX 10.14.1, *) {
                    desc += " padded with \(paddingConstant)"
                } else {
                    desc += " padded with zero"
                }
            case .mirror:
                if #available(OSX 10.14.1, *) {
                    desc += " padded by mirroring"
                } else {
                    desc += " padded with zero"
               }
            case .mirrorWithEdge:
                if #available(OSX 10.14.1, *) {
                    desc += " padded by mirroring with edge"
                } else {
                    desc += " padded with zero"
                }
            }
            return desc
        }
        return ""
    }
    
    func getPaddingSize() -> (left: Int, top: Int, right: Int, bottom: Int)
    {
        if (type != .Convolution && type != .Pooling) { return (left: 0, top: 0, right: 0, bottom: 0) }

            //  Get the half-kernels (extension if padding)
        let halfKernelX = (kernelWidth - 1) / 2
        let halfKernelY = (kernelHeight - 1) / 2
        
        //  Get the padding in each dimension
        var leftPadding = 0
        if (XPaddingMethod != .ValidOnly) { leftPadding = halfKernelX }
        if (XPaddingMethod == .SizeFull) { leftPadding = kernelWidth - 1 }
        var topPadding = 0
        if (YPaddingMethod != .ValidOnly) { topPadding = halfKernelY }
        if (YPaddingMethod == .SizeFull) { topPadding = kernelHeight - 1 }
        var rightPadding = 0
        if (XPaddingMethod != .ValidOnly) { rightPadding = halfKernelX }
        if (XPaddingMethod == .SizeFull) { rightPadding = kernelWidth - 1 }
        var bottomPadding = 0
        if (YPaddingMethod != .ValidOnly) { bottomPadding = halfKernelY }
        if (YPaddingMethod == .SizeFull) { bottomPadding = kernelHeight - 1 }

        return (left: leftPadding, top: topPadding, right: rightPadding, bottom: bottomPadding)
    }
    
    func subTypeString() -> String
    {
        switch (type) {
        case .Convolution:
            if let subtype = ConvolutionSubType(rawValue: subType) {
                return subtype.subTypeString
            }
            
        case .FullyConnected:
            if let subtype = FullyConnectedSubType(rawValue: subType) {
                return subtype.subTypeString
            }
            
        case .Pooling:
            if let subtype = PoolingSubType(rawValue: subType) {
                return subtype.subTypeString
            }
            
        case .Neuron:
            if let subtype = NeuronSubType(rawValue: subType) {
                return subtype.subTypeString
            }
            
        case .SoftMax:
            if let subtype = SoftMaxSubType(rawValue: subType) {
                return subtype.subTypeString
            }
            
        case .Normalization:
            if let subtype = NormalizationSubType(rawValue: subType) {
                return subtype.subTypeString
            }
            
        case .UpSampling:
            if let subtype = UpSamplingSubType(rawValue: subType) {
                return subtype.subTypeString
            }
            
        case .DropOut:
            if let subtype = DropOutSubType(rawValue: subType) {
                return subtype.subTypeString
            }

        default:
            return "<No implementation>"
        }
        
        return "<Invalid subtype>"
    }
    
    func getParameterString() -> String
    {
        switch (type) {
        case .Convolution:
            if let subtype = ConvolutionSubType(rawValue: subType) {
                switch (subtype) {
                case .Normal, .Binary, .Transpose:
                    return "Kernel \(kernelWidth)✗\(kernelHeight), Stride X: \(strideX), Stride Y: \(strideY)"
                }
            }
            else {
                return "<Invalid subtype>"
            }

        case .FullyConnected:
            if let subtype = FullyConnectedSubType(rawValue: subType) {
                switch (subtype) {
                case .NormalWeights, .BinaryWeights:
                    return "\(numChannels) Neurons"
                }
            }
            else {
                return "<Invalid subtype>"
            }

        case .Pooling:
            return "Kernel \(kernelWidth)✗\(kernelHeight), Stride X: \(strideX), Stride Y: \(strideY)"
            
        case .Neuron:
            return ""
            
        case .SoftMax:
            return ""
            
        case .Normalization:
            if let subtype = NormalizationSubType(rawValue: subType) {
                switch (subtype) {
                case .CrossCannel:
                    let kernelSize = Int(additionalData[0] + 0.1)
                    return "Kernel Size : \(kernelSize)"
                case .LocalContrast:
                    let kernelSizeX = Int(additionalData[0] + 0.1)
                    let kernelSizeY = Int(additionalData[1] + 0.1)
                    return "Kernel-X : \(kernelSizeX),  Kernel-Y : \(kernelSizeY)"
                case .Spatial:
                    let kernelSizeX = Int(additionalData[0] + 0.1)
                    let kernelSizeY = Int(additionalData[1] + 0.1)
                    return "Kernel-X : \(kernelSizeX),  Kernel-Y : \(kernelSizeY)"
                case .Batch:
                    return ""
                case .Instance:
                    return ""
                }
            }

        case .UpSampling:
            let scaleFactorX = Int(additionalData[0] + 0.1)
            let scaleFactorY = Int(additionalData[1] + 0.1)
            return "scale-X : \(scaleFactorX),  scale-Y : \(scaleFactorY)"

        case .DropOut:
            return "Keep Prob. \(additionalData[0])"

        default:
            return "<No implementation>"
        }
        return ""
    }
    
    func getAdditionalDataInfo() -> [AdditionalDataInfo]
    {
        var additionalDataInfo : [AdditionalDataInfo] = []
        
        switch (type) {
        case .Convolution:
            if let subtype = ConvolutionSubType(rawValue: subType) {
                switch (subtype) {
                case .Binary:
                    additionalDataInfo.append(AdditionalDataInfo(type: .float, name: "Scaling Factor", minimum: 0.0, maximum: 100.0))
                    additionalDataInfo.append(AdditionalDataInfo(type: .int, name: "Type : 0-Binary Weight, 1-XNOR, 2-AND", minimum: 0.0, maximum: 2.0))
                    additionalDataInfo.append(AdditionalDataInfo(type: .bool, name: "Use Beta Scaling", minimum: 0.0, maximum: 1.0))

                default:
                    return []
                }
            }
            else {
                return []
            }
            
        case .Pooling:
            if let subtype = PoolingSubType(rawValue: subType) {
                switch (subtype) {
                case .DilatedMax:
                    additionalDataInfo.append(AdditionalDataInfo(type: .int, name: "Dilation X", minimum: 1.0, maximum: 100.0))
                    additionalDataInfo.append(AdditionalDataInfo(type: .int, name: "Dilation Y", minimum: 1.0, maximum: 100.0))

                default:
                    return []
                }
            }
            else {
                return []
            }
            
        case .FullyConnected:
            if let subtype = FullyConnectedSubType(rawValue: subType) {
                switch (subtype) {
                case .BinaryWeights:
                    additionalDataInfo.append(AdditionalDataInfo(type: .float, name: "Scaling Factor", minimum: 0.0, maximum: 100.0))
                    additionalDataInfo.append(AdditionalDataInfo(type: .int, name: "Type : 0-Binary Weight, 1-XNOR, 2-AND", minimum: 0.0, maximum: 2.0))
                    additionalDataInfo.append(AdditionalDataInfo(type: .bool, name: "Use Beta Scaling", minimum: 0.0, maximum: 1.0))
                    
                default:
                    return []
                }
            }
            else {
                return []
            }
            
        case .Neuron:
            if let subtype = NeuronSubType(rawValue: subType) {
                switch (subtype) {
                case .ELU:
                    additionalDataInfo.append(AdditionalDataInfo(type: .float, name: "ELU Scale Factor", minimum: 0.0, maximum: 10.0))
                case .HardSigmoid:
                    additionalDataInfo.append(AdditionalDataInfo(type: .float, name: "Slope", minimum: 0.0, maximum: 10.0))
                    additionalDataInfo.append(AdditionalDataInfo(type: .float, name: "Intercept", minimum: 0.0, maximum: 1.0))
                case .Linear:
                    additionalDataInfo.append(AdditionalDataInfo(type: .float, name: "Slope", minimum: 0.0, maximum: 10.0))
                    additionalDataInfo.append(AdditionalDataInfo(type: .float, name: "Intercept", minimum: 0.0, maximum: 1.0))
                case .PReLU:
                    for i in 0..<additionalData.count {
                        additionalDataInfo.append(AdditionalDataInfo(type: .float, name: "Channel \(i) parameter", minimum: 0.0, maximum: 10.0))
                    }
                case .ReLUN:
                    additionalDataInfo.append(AdditionalDataInfo(type: .float, name: "Slope", minimum: 0.0, maximum: 10.0))
                    additionalDataInfo.append(AdditionalDataInfo(type: .float, name: "Clamp", minimum: 0.0, maximum: 1.0))
                case .ReLU:
                    additionalDataInfo.append(AdditionalDataInfo(type: .float, name: "Leaky Slope", minimum: 0.0, maximum: 10.0))
                case .SoftPlus:
                    additionalDataInfo.append(AdditionalDataInfo(type: .float, name: "Scale", minimum: 0.0, maximum: 10.0))
                    additionalDataInfo.append(AdditionalDataInfo(type: .float, name: "Power", minimum: -10.0, maximum: 10.0))
                case .TanH:
                    additionalDataInfo.append(AdditionalDataInfo(type: .float, name: "Scale", minimum: 0.0, maximum: 10.0))
                    additionalDataInfo.append(AdditionalDataInfo(type: .float, name: "Multiplier", minimum: 0.0, maximum: 10.0))

                default:
                    return []
                }
            }
            
        case .SoftMax:
            return []
            
        case .Normalization:
            if let subtype = NormalizationSubType(rawValue: subType) {
                switch (subtype) {
                case .CrossCannel:
                    additionalDataInfo.append(AdditionalDataInfo(type: .int, name: "Kernel Size", minimum: 1.0, maximum: 100.0))
                case .LocalContrast:
                    additionalDataInfo.append(AdditionalDataInfo(type: .int, name: "Kernel Width", minimum: 1.0, maximum: 100.0))
                    additionalDataInfo.append(AdditionalDataInfo(type: .int, name: "Kernel Height", minimum: 1.0, maximum: 100.0))
                    additionalDataInfo.append(AdditionalDataInfo(type: .float, name: "P0", minimum: 0.0, maximum: 100.0))
                    additionalDataInfo.append(AdditionalDataInfo(type: .float, name: "PM", minimum: 0.0, maximum: 100.0))
                    additionalDataInfo.append(AdditionalDataInfo(type: .float, name: "PS", minimum: 0.0, maximum: 100.0))
                case .Spatial:
                    additionalDataInfo.append(AdditionalDataInfo(type: .int, name: "Kernel Width", minimum: 1.0, maximum: 100.0))
                    additionalDataInfo.append(AdditionalDataInfo(type: .int, name: "Kernel Height", minimum: 1.0, maximum: 100.0))
                case .Batch:
                    return []
                case .Instance:
                    return []
                }
            }

        case .UpSampling:
            additionalDataInfo.append(AdditionalDataInfo(type: .int, name: "Scale Factor X", minimum: 1.0, maximum: 100.0))
            additionalDataInfo.append(AdditionalDataInfo(type: .int, name: "Scale Factor Y", minimum: 1.0, maximum: 100.0))
            if (subType == 1) { additionalDataInfo.append(AdditionalDataInfo(type: .bool, name: "Align Corners", minimum: 0.0, maximum: 1.0)) }

        case .DropOut:
            additionalDataInfo.append(AdditionalDataInfo(type: .float, name: "Keep Probability", minimum: 0.0, maximum: 1.0))
            additionalDataInfo.append(AdditionalDataInfo(type: .int, name: "Random Seed", minimum: 0.0, maximum: Float(Int.max)))
            additionalDataInfo.append(AdditionalDataInfo(type: .int, name: "Stride X", minimum: 0.0, maximum: 100.0))
            additionalDataInfo.append(AdditionalDataInfo(type: .int, name: "Stride Y", minimum: 0.0, maximum: 100.0))
            additionalDataInfo.append(AdditionalDataInfo(type: .int, name: "Stride Depth", minimum: 0.0, maximum: 100.0))

        default:
            return []
        }

        return additionalDataInfo
    }
    
    
    func getNumParameters(inputDimensions: [Int]) -> Int
    {
        switch (type) {
        case .Convolution:
            let numInputs = kernelWidth * kernelHeight * inputChannels
            let numWeights = numInputs * numChannels
            if (useBiasTerms) { return numWeights + numChannels}
            return numWeights
        case .FullyConnected:
            let numInputs = inputDimensions.reduce(1, *)
            let numWeights = numInputs * numChannels
            if (useBiasTerms) { return numWeights + numChannels}
            return numWeights
        default:
            return 0
        }
     }
    
    func initializeAdditionalDataInfo()
    {
        switch (type) {
        case .Convolution:
            if let subtype = ConvolutionSubType(rawValue: subType) {
                switch (subtype) {
                case .Binary:
                    additionalData[0] = 1.0
                    additionalData[1] = 0.0
                    additionalData[2] = 0.0
                    
                default:
                    return
                }
            }
            else {
                return
            }
            
        case .Pooling:
            if let subtype = PoolingSubType(rawValue: subType) {
                switch (subtype) {
                case .DilatedMax:
                    additionalData[0] = 1.0
                    additionalData[1] = 1.0

                default:
                    return
                }
            }
            else {
                return
            }
            
        case .FullyConnected:
            if let subtype = FullyConnectedSubType(rawValue: subType) {
                switch (subtype) {
                case .BinaryWeights:
                    additionalData[0] = 1.0
                    additionalData[1] = 0.0
                    additionalData[2] = 0.0
                    
                default:
                    return
                }
            }
            else {
                return
            }
            
        case .Neuron:
            if let subtype = NeuronSubType(rawValue: subType) {
                switch (subtype) {
                case .ELU:
                    additionalData[0] = 0.0
                case .HardSigmoid:
                    additionalData[0] = 1.0
                    additionalData[1] = 0.0
                case .Linear:
                    additionalData[0] = 1.0
                    additionalData[1] = 0.0
                case .PReLU:
                    for i in 0..<additionalData.count {
                        additionalData[i] = 0.0
                    }
                case .ReLUN:
                    additionalData[0] = 1.0
                    additionalData[1] = 1.0
                case .ReLU:
                    additionalData[0] = 0.0
                case .SoftPlus:
                    additionalData[0] = 1.0
                    additionalData[1] = 1.0
                case .TanH:
                    additionalData[0] = 1.0
                    additionalData[1] = 1.0

                default:
                    return
                }
            }
            
        case .SoftMax:
            return
            
        case .Normalization:
            if let subtype = NormalizationSubType(rawValue: subType) {
                switch (subtype) {
                case .CrossCannel:
                    additionalData[0] = 1.0
                case .LocalContrast:
                    additionalData[0] = 1.0
                    additionalData[1] = 1.0
                    additionalData[2] = 1.0
                    additionalData[3] = 1.0
                    additionalData[4] = 1.0
                case .Spatial:
                    additionalData[0] = 1.0
                    additionalData[1] = 1.0
                case .Batch:
                    return
                case .Instance:
                    return
               }
            }

        case .UpSampling:
            additionalData[0] = 1.0
            additionalData[1] = 1.0
            if (subType == 1) { additionalData[2] = 1.0 }

        case .DropOut:
            additionalData[0] = 0.1
            additionalData[1] = Float(Int.random(in: 0...Int.max))
            additionalData[2] = 1.0
            additionalData[3] = 1.0
            additionalData[4] = 1.0

        default:
            return
        }
        
        return
    }

    func initializeWeights(inputDimensions: [Int])
    {
        //  Remember the input channels for the descriptor later
        inputChannels = inputDimensions[2] * inputDimensions[3]

        //  Convolution layer
        if (type == .Convolution) {
            let numInputs = kernelWidth * kernelHeight * inputChannels
            let numWeights = numInputs * numChannels
            let variance = 2/Float(numInputs)
            let deviation = sqrt(variance)
            weightArray = [Float](repeating: 0.0, count: numWeights)
            if let sub = ConvolutionSubType(rawValue: subType) {
                if (sub == .Binary) {
                    for i in 0..<numWeights {
                        weightArray![i] = Float(Int.random(in: 0...1))
                    }
                }
                else {
                    for i in 0..<numWeights {
                        weightArray![i] = getGaussianRandom(deviation)
                    }
                }
                
                //  1 bias per channel neuron
                if (useBiasTerms) {
                    biases = [Float](repeating: 0.0, count: numChannels)
                }
                else {
                    biases = nil
                }
            }
        }

        //  Fully Connected layer
        if (type == .FullyConnected) {
            let numInputs = inputDimensions.reduce(1, *)
            let numWeights = numInputs * numChannels
            let variance = 2/Float(numInputs)
            let deviation = sqrt(variance)
            weightArray = [Float](repeating: 0.0, count: numWeights)
            if let sub = FullyConnectedSubType(rawValue: subType) {
                if (sub == .BinaryWeights) {
                    for i in 0..<numWeights {
                        weightArray![i] = Float(Int.random(in: 0...1))
                    }
                }
                else {
                    for i in 0..<numWeights {
                        weightArray![i] = getGaussianRandom(deviation)
                    }
                }
            }
            
            //  1 bias per output neuron
            if (useBiasTerms) {
                biases = [Float](repeating: 0.0, count: numChannels)
            }
            else {
                biases = nil
            }
            
            //  Fully connected nodes have a kernel size based on the input size
            kernelWidth = inputDimensions[0]
            kernelHeight = inputDimensions[1]
        }
     }

    func initializeWeightsForTest(inputDimensions: [Int])
    {
        //  Remember the input channels for the descriptor later
        inputChannels = inputDimensions[2]
        
        //  Convolution layer
        if (type == .Convolution) {
            let numWeights = kernelWidth * kernelHeight * inputChannels * numChannels
            weightArray = [Float](repeating: 0.0, count: numWeights)
            if let sub = ConvolutionSubType(rawValue: subType) {
                if (sub == .Binary) {
                    for i in 0..<numWeights {
                        weightArray![i] = 1.0
                    }
                }
                else {
                    for i in 0..<numWeights {
                        weightArray![i] = 0.5
                    }
                }
                
                //  1 bias per channel neuron
                if (useBiasTerms) {
                    biases = [Float](repeating: 0.0, count: numChannels)
                }
                else {
                    biases = nil
                }
            }
        }
        
        //  Fully Connected layer
        if (type == .FullyConnected) {
            let numInputs = inputDimensions.reduce(1, *)
            let numWeights = numInputs * numChannels
            weightArray = [Float](repeating: 0.0, count: numWeights)
            if let sub = FullyConnectedSubType(rawValue: subType) {
                if (sub == .BinaryWeights) {
                    for i in 0..<numWeights {
                        weightArray![i] = Float(Int.random(in: 0...1))
                    }
                }
                else {
                    for i in 0..<numWeights {
                        weightArray![i] = Float.random(in: -1 ... 1)
                    }
                }
            }
            
            //  1 bias per output neuron
            if (useBiasTerms) {
                biases = [Float](repeating: 0.0, count: numChannels)
            }
            else {
                biases = nil
            }
            
            //  Fully connected nodes have a kernel size based on the input size
            kernelWidth = inputDimensions[0]
            kernelHeight = inputDimensions[1]
        }
    }
    
    func getGaussianRandom(_ deviation: Float) -> Float       //  Assumes zero mean
    {
        let x1 = Float.random(in: 0...1)
        let x2 = Float.random(in: 0...1)
        let z1 = sqrt(-2 * log(x1)) * cos(2 * Float.pi * x2) // z1 is normally distributed
        return z1 * deviation
    }

    func getNode(inputImage: MPSNNImageNode) -> MPSNNImageNode
    {
        switch (type) {
        case .Convolution:
            if let subtype = ConvolutionSubType(rawValue: subType) {
                var node : MPSCNNConvolutionNode
                switch (subtype) {
                case .Normal:
                    node = MPSCNNConvolutionNode(source: inputImage, weights: self)
                case .Binary:
                    var intValue = UInt(additionalData[1])
                    if (intValue < 0 || intValue > 2) {
                        additionalData[1] = 0.0
                        intValue = 0
                    }
                    let binaryType = MPSCNNBinaryConvolutionType(rawValue: intValue)!
                    var flags = MPSCNNBinaryConvolutionFlags.none
                    if (additionalData[2] > 0.5) { flags = .useBetaScaling }
                    node = MPSCNNBinaryConvolutionNode(source: inputImage, weights: self,
                                                       scaleValue : additionalData[0], type: binaryType, flags : flags)
               case .Transpose:
                    node = MPSCNNConvolutionTransposeNode(source: inputImage, weights: self)
                }
                
                //  Set the padding policy
                let policy = Padding()
                policy.layer = self
                node.paddingPolicy = policy
                
                //  Keep a reference to the node so it isn't removed by memory management
                lastNode = node
                return node.resultImage
            }
            else {
                fatalError("layer type has not been implemented")
                
            }
            
        case .Pooling:
            if let subtype = PoolingSubType(rawValue: subType) {
                var node : MPSNNFilterNode
                switch (subtype) {
                case .Average:
                    node = MPSCNNPoolingAverageNode(source: inputImage, kernelWidth: kernelWidth, kernelHeight: kernelHeight, strideInPixelsX: strideX, strideInPixelsY: strideY)
                case .L2Norm:
                    node = MPSCNNPoolingL2NormNode(source: inputImage, kernelWidth: kernelWidth, kernelHeight: kernelHeight, strideInPixelsX: strideX, strideInPixelsY: strideY)
                case .Max:
                    node = MPSCNNPoolingMaxNode(source: inputImage, kernelWidth: kernelWidth, kernelHeight: kernelHeight, strideInPixelsX: strideX, strideInPixelsY: strideY)
                case .DilatedMax:
                    node = MPSCNNDilatedPoolingMaxNode(source: inputImage, kernelWidth: kernelWidth, kernelHeight: kernelHeight, strideInPixelsX: strideX, strideInPixelsY: strideY, dilationRateX: Int(additionalData[0]), dilationRateY: Int(additionalData[1]))
                }
                
                //  Set the padding policy
                let policy = Padding()
                policy.layer = self
                node.paddingPolicy = policy
                
                //  Keep a reference to the node so it isn't removed by memory management
                lastNode = node
                return node.resultImage
            }
            else {
                fatalError("layer type has not been implemented")            }

        case .FullyConnected:
            if let subtype = FullyConnectedSubType(rawValue: subType) {
                var node : MPSCNNConvolutionNode
                switch (subtype) {
                case .NormalWeights:
                    node = MPSCNNFullyConnectedNode(source: inputImage, weights: self)
                    
                case .BinaryWeights:
                    var intValue = UInt(additionalData[1])
                    if (intValue < 0 || intValue > 2) {
                        additionalData[1] = 0.0
                        intValue = 0
                    }
                    let binaryType = MPSCNNBinaryConvolutionType(rawValue: intValue)!
                    var flags = MPSCNNBinaryConvolutionFlags.none
                    if (additionalData[2] > 0.5) { flags = .useBetaScaling }
                    node = MPSCNNBinaryFullyConnectedNode(source: inputImage, weights: self,
                                                       scaleValue : additionalData[0], type: binaryType, flags : flags)
                }
                
                //  Keep a reference to the node so it isn't removed by memory management
                lastNode = node
                return node.resultImage
            }
            else {
                fatalError("layer type has not been implemented")
            }
            
        case .Neuron:
                var node : MPSCNNNeuronNode
                if let subtype = NeuronSubType(rawValue: subType) {
                switch (subtype) {
                case .Absolute:
                    node = MPSCNNNeuronAbsoluteNode(source: inputImage)
                case .ELU:
                    node = MPSCNNNeuronELUNode(source: inputImage, a: additionalData[0])
                case .HardSigmoid:
                    node = MPSCNNNeuronHardSigmoidNode(source: inputImage, a: additionalData[0], b: additionalData[1])
                case .Linear:
                    node = MPSCNNNeuronLinearNode(source: inputImage, a: additionalData[0], b: additionalData[1])
                case .PReLU:
                    var data = Data()
                    for value in additionalData {
                        let floatdata = withUnsafeBytes(of: value) { Data($0) }
                        data.append(floatdata)
                    }
                    data.append(1)
                    node = MPSCNNNeuronPReLUNode(source: inputImage, aData: data)
                case .ReLUN:
                    node = MPSCNNNeuronReLUNNode(source: inputImage, a: additionalData[0], b: additionalData[1])
                case .ReLU:
                    node = MPSCNNNeuronReLUNode(source: inputImage, a: additionalData[0])
                case .Sigmoid:
                    node = MPSCNNNeuronSigmoidNode(source: inputImage)
                case .SoftPlus:
                    node = MPSCNNNeuronSoftPlusNode(source: inputImage, a: additionalData[0], b: additionalData[1])
                case .SoftSign:
                    node = MPSCNNNeuronSoftSignNode(source: inputImage)
                case .TanH:
                    node = MPSCNNNeuronTanHNode(source: inputImage, a: additionalData[0], b: additionalData[1])
                case .Exponential:
                    node = MPSCNNNeuronExponentialNode(source: inputImage)
                case .Logarithm:
                    node = MPSCNNNeuronLogarithmNode(source: inputImage)
                case .Power:
                    node = MPSCNNNeuronPowerNode(source: inputImage)
                }
                //  Keep a reference to the node so it isn't removed by memory management
                lastNode = node
                return node.resultImage
            }
            else {
                fatalError("layer type has not been implemented")
            }

        case .SoftMax:
            var node : MPSNNFilterNode
            if let subtype = SoftMaxSubType(rawValue: subType) {
                switch (subtype) {
                case .SoftMax:
                    node = MPSCNNSoftMaxNode(source: inputImage)
                case .LogSoftMax:
                    node = MPSCNNLogSoftMaxNode(source: inputImage)
                }
                //  Keep a reference to the node so it isn't removed by memory management
                lastNode = node
                return node.resultImage
            }
            else {
                fatalError("layer type has not been implemented")
            }

        case .Normalization:
            var node : MPSNNFilterNode
            if let subtype = NormalizationSubType(rawValue: subType) {
                switch (subtype) {
                case .CrossCannel:
                    node = MPSCNNCrossChannelNormalizationNode(source : inputImage, kernelSize: Int(additionalData[0]+0.1))
                case .LocalContrast:
                    let localNode = MPSCNNLocalContrastNormalizationNode(source : inputImage)
                    localNode.kernelWidth = Int(additionalData[0] + 0.1)
                    localNode.kernelHeight = Int(additionalData[1] + 0.1)
                    localNode.p0 = additionalData[2]
                    localNode.ps = additionalData[3]
                    localNode.p0 = additionalData[4]
                    node = localNode
                case .Spatial:
                    let localNode = MPSCNNSpatialNormalizationNode(source : inputImage)
                    localNode.kernelWidth = Int(additionalData[0] + 0.1)
                    localNode.kernelHeight = Int(additionalData[1] + 0.1)
                    node = localNode
                case .Batch:
                    let normalizationData = BatchNormalizationData()
                    normalizationData.layer = self
                    let localNode = MPSCNNBatchNormalizationNode(source : inputImage, dataSource: normalizationData)
                    node = localNode
                case .Instance:
                    let normalizationData = InstanceNormalizationData()
                    normalizationData.layer = self
                    let localNode = MPSCNNInstanceNormalizationNode(source : inputImage, dataSource: normalizationData)
                    node = localNode
                }
                //  Keep a reference to the node so it isn't removed by memory management
                lastNode = node
                return node.resultImage
            }
            else {
                fatalError("layer type has not been implemented")
            }
            return node.resultImage

        case .UpSampling:
            var node : MPSNNFilterNode
            if let subtype = UpSamplingSubType(rawValue: subType) {
                switch (subtype) {
                case .BiLinear:
                    let scaleX = Int(additionalData[0] + 0.1)
                    let scaleY = Int(additionalData[1] + 0.1)
                    let align = (additionalData[2] > 0.5)
                    node = MPSCNNUpsamplingBilinearNode(source: inputImage, integerScaleFactorX: scaleX, integerScaleFactorY: scaleY, alignCorners: align)
                case .Nearest:
                    let scaleX = Int(additionalData[0] + 0.1)
                    let scaleY = Int(additionalData[1] + 0.1)
                    node = MPSCNNUpsamplingNearestNode(source: inputImage, integerScaleFactorX: scaleX, integerScaleFactorY: scaleY)
                }
                //  Keep a reference to the node so it isn't removed by memory management
                lastNode = node
                return node.resultImage
            }
            else {
                fatalError("layer type has not been implemented")
            }
            return node.resultImage

        case .DropOut:
            let seed = Int(additionalData[1] + 0.1)
            let stride = MTLSize(width: Int(additionalData[2] + 0.1), height: Int(additionalData[3] + 0.1), depth: Int(additionalData[4] + 0.1))
            let node = MPSCNNDropoutNode(source: inputImage, keepProbability: additionalData[0], seed: seed, maskStrideInPixels: stride)
            //  Keep a reference to the node so it isn't removed by memory management
            lastNode = node
            return node.resultImage

        default:
            fatalError("layer type has not been implemented")
        }

    }
    
    func getGradientNode(inputImage: MPSNNImageNode) -> MPSNNImageNode
    {
        if (lastNode == nil) {
            //Error
        }
        
        //  Clear any update vectors - we are starting a new training session
        inputMomentumVectors = nil
        inputSumOfSquaresVectors = nil
        inputVelocityVectors = nil
        
        //  Get the node
        let node = lastNode!.gradientFilter(withSource: inputImage)
        lastGradientNode = node  //  Keep a reference to the node so it isn't removed by memory management
        return node.resultImage
    }
    
    func setWeightAndBiasState(device: MTLDevice)
    {
        //  Ignore if we don't have trainable weights
        if (type == .Convolution || type == .FullyConnected) {
            weightsAndBiasState = MPSCNNConvolutionWeightsAndBiasesState(device: device, cnnConvolutionDescriptor:descriptor())
        }
    }
    
    func createUpdateVectors(device: MTLDevice) -> [MPSVector]?
    {
        //  Start with an empty array
        var vectors : [MPSVector] = []
        
        //  Get the weight vector
        if (weightArray == nil) { return nil }
        let count = weightArray!.count
        guard let buffer = device.makeBuffer(bytes: Array<Float32>(repeating: 0.0, count: count), length: count * MemoryLayout<Float32>.size, options: [.storageModeShared]) else {
                return nil
        }
        let desc = MPSVectorDescriptor(length: count, dataType: MPSDataType.float32)
        let vector = MPSVector(buffer: buffer, descriptor: desc)
        vectors.append(vector)
        
        //  If biases are used, add those
        if (useBiasTerms) {
            let count = numChannels
            guard let buffer = device.makeBuffer(bytes: Array<Float32>(repeating: 0.0, count: count), length: count * MemoryLayout<Float32>.size, options: [.storageModeShared]) else {
                return nil
            }
            let desc = MPSVectorDescriptor(length: count, dataType: MPSDataType.float32)
            let vector = MPSVector(buffer: buffer, descriptor: desc)
            vectors.append(vector)
        }
        
        return vectors
    }

    func setMainLearningRate(_ rate : Float) {
        currentLearningRate = learningRateMultiplier * rate
        updateOptimizer = nil           //  optimizer has learning rate, so must be recreated
    }
    
    func synchronizeWeightsAndBias(buffer: MTLCommandBuffer)
    {
        if let wbs = weightsAndBiasState {
            wbs.synchronize(on: buffer)
        }
    }
    
    func extractWeightsAndBias()
    {
        if let wbs = weightsAndBiasState {
            weightArray = wbs.weights.toArray(type: Float.self)
            if (useBiasTerms) {
                biases = wbs.biases?.toArray(type: Float.self)
            }
        }
    }
    
    func getUpdateRuleString() -> String
    {
        var string : String
        
        switch (updateRule) {
        case .SGD:
            if (momentumScale > 0.0) {
                string = "SGD+Momentum"
            }
            else {
                string = "SGD"
            }
        case .RMSProp:
            string = "RMS Prop."
        case .Adam:
            string = "Adam"
        }
        
        if (applyGradientClipping) {
            string += ", Clipping"
        }
        
        if (regularizationType == .L1) {
            string += ", L1 Reg."
        }
        else if (regularizationType == .L1) {
            string += ", L2 Reg."
        }

        return string
    }

    // MARK: - NSCoding
    
    required init?(coder aDecoder: NSCoder) {
        let version = aDecoder.decodeInteger(forKey: "fileVersion")
        if (version > 1) { return nil }
        
        type = LayerType(rawValue: aDecoder.decodeInteger(forKey: "layerType"))!
        subType = aDecoder.decodeInteger(forKey: "layerSubType")
        
        kernelWidth = aDecoder.decodeInteger(forKey: "kernelWidth")
        kernelHeight = aDecoder.decodeInteger(forKey: "kernelHeight")
        strideX = aDecoder.decodeInteger(forKey: "strideX")
        strideY = aDecoder.decodeInteger(forKey: "strideY")
        numChannels = aDecoder.decodeInteger(forKey: "numChannels")
        useBiasTerms = aDecoder.decodeBool(forKey: "useBiasTerms")

        weightArray = aDecoder.decodeObject(forKey: "weights") as! [Float]?
        biases = aDecoder.decodeObject(forKey: "biases") as! [Float]?

        inputChannels = aDecoder.decodeInteger(forKey: "inputChannels")
        layerName = aDecoder.decodeObject(forKey: "layerName") as! String?

        XPaddingMethod = PaddingMethod(rawValue: aDecoder.decodeInteger(forKey: "XPaddingMethod"))!
        YPaddingMethod = PaddingMethod(rawValue: aDecoder.decodeInteger(forKey: "YPaddingMethod"))!
        featurePaddingMethod = PaddingMethod(rawValue: aDecoder.decodeInteger(forKey: "featurePaddingMethod"))!
        XOffset = aDecoder.decodeInteger(forKey: "XOffset")
        YOffset = aDecoder.decodeInteger(forKey: "YOffset")
        featureOffset = aDecoder.decodeInteger(forKey: "featureOffset")
        clipWidth = aDecoder.decodeInteger(forKey: "clipWidth")
        clipHeight = aDecoder.decodeInteger(forKey: "clipHeight")
        clipDepth = aDecoder.decodeInteger(forKey: "clipDepth")
        edgeMode = MPSImageEdgeMode(rawValue: UInt(aDecoder.decodeInteger(forKey: "edgeMode")))!
        paddingConstant = aDecoder.decodeFloat(forKey: "paddingConstant")
        
        updateRule = UpdateRule(rawValue: aDecoder.decodeInteger(forKey: "updateRule"))!
        learningRateMultiplier = aDecoder.decodeFloat(forKey: "learningRateMultiplier")
        momentumScale = aDecoder.decodeFloat(forKey: "momentumScale")
        useNesterovMomentum = aDecoder.decodeBool(forKey: "useNestrovMomentum")
        epsilon = aDecoder.decodeFloat(forKey: "epsilon")
        beta1 = aDecoder.decodeDouble(forKey: "beta1")
        beta2 = aDecoder.decodeDouble(forKey: "beta2")
        timeStep = aDecoder.decodeInteger(forKey: "timeStep")
        gradientRescale = aDecoder.decodeFloat(forKey: "gradientRescale")
        applyGradientClipping = aDecoder.decodeBool(forKey: "applyGradientClipping")
        gradientClipMax = aDecoder.decodeFloat(forKey: "gradientClipMax")
        gradientClipMin = aDecoder.decodeFloat(forKey: "gradientClipMin")
        regularizationType = MPSNNRegularizationType(rawValue: UInt(aDecoder.decodeInteger(forKey: "regularizationType")))!
        regularizationScale = aDecoder.decodeFloat(forKey: "regularizationScale")

        additionalData = aDecoder.decodeObject(forKey: "additionalData") as! [Float]

        super.init()
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(1, forKey: "fileVersion")
        aCoder.encode(type.rawValue, forKey: "layerType")
        aCoder.encode(subType, forKey: "layerSubType")
        aCoder.encode(kernelWidth, forKey: "kernelWidth")
        aCoder.encode(kernelHeight, forKey: "kernelHeight")
        aCoder.encode(strideX, forKey: "strideX")
        aCoder.encode(strideY, forKey: "strideY")
        aCoder.encode(numChannels, forKey: "numChannels")
        aCoder.encode(useBiasTerms, forKey: "useBiasTerms")
        aCoder.encode(weightArray, forKey: "weights")
        aCoder.encode(biases, forKey: "biases")
        aCoder.encode(inputChannels, forKey: "inputChannels")
        aCoder.encode(layerName, forKey: "layerName")

        aCoder.encode(XPaddingMethod.rawValue, forKey: "XPaddingMethod")
        aCoder.encode(YPaddingMethod.rawValue, forKey: "YPaddingMethod")
        aCoder.encode(featurePaddingMethod.rawValue, forKey: "featurePaddingMethod")
        aCoder.encode(XOffset, forKey: "XOffset")
        aCoder.encode(YOffset, forKey: "YOffset")
        aCoder.encode(featureOffset, forKey: "featureOffset")
        aCoder.encode(clipWidth, forKey: "clipWidth")
        aCoder.encode(clipHeight, forKey: "clipHeight")
        aCoder.encode(clipDepth, forKey: "clipDepth")
        aCoder.encode(Int(edgeMode.rawValue), forKey: "edgeMode")
        aCoder.encode(paddingConstant, forKey: "paddingConstant")
        
        aCoder.encode(updateRule.rawValue, forKey: "updateRule")
        aCoder.encode(learningRateMultiplier, forKey: "learningRateMultiplier")
        aCoder.encode(momentumScale, forKey: "momentumScale")
        aCoder.encode(useNesterovMomentum, forKey: "useNestrovMomentum")
        aCoder.encode(epsilon, forKey: "epsilon")
        aCoder.encode(beta1, forKey: "beta1")
        aCoder.encode(beta2, forKey: "beta2")
        aCoder.encode(timeStep, forKey: "timeStep")
        aCoder.encode(gradientRescale, forKey: "gradientRescale")
        aCoder.encode(applyGradientClipping, forKey: "applyGradientClipping")
        aCoder.encode(gradientClipMax, forKey: "gradientClipMax")
        aCoder.encode(gradientClipMin, forKey: "gradientClipMin")
        aCoder.encode(Int(regularizationType.rawValue), forKey: "regularizationType")
        aCoder.encode(regularizationScale, forKey: "regularizationScale")

        aCoder.encode(additionalData, forKey: "additionalData")
     }
    
    
    //  MARK: NSCopying
    func copy(with zone: NSZone? = nil) -> Any {
        fatalError("copyWithZone not implemented")
    }

    
    //  MARK: - MPSCNNConvolutionDataSource
    func biasTerms() -> UnsafeMutablePointer<Float>?
    {
        if (biases == nil || !useBiasTerms) { return nil }
        
        return UnsafeMutableRawPointer(mutating: biases!).bindMemory(to: Float.self, capacity: biases!.count * MemoryLayout<Float>.stride)
    }
    
    func dataType() -> MPSDataType
    {
        return .float32
    }
    
    func descriptor() -> MPSCNNConvolutionDescriptor
    {
        let desc = MPSCNNConvolutionDescriptor(kernelWidth: kernelWidth,
                                               kernelHeight: kernelHeight,
                                               inputFeatureChannels: inputChannels,
                                               outputFeatureChannels: numChannels)
        return desc
   }
    
    func label() -> String?
    {
        return type.typeString + " - " + subTypeString()
    }
    
    func load() -> Bool
    {
        return true
    }
    
    func purge()
    {
        //  No purging at this time
    }
    
    func weights() -> UnsafeMutableRawPointer
    {
        return UnsafeMutableRawPointer(mutating: weightArray!)
    }
    
    func update(with gradientState: MPSCNNConvolutionGradientState, sourceState: MPSCNNConvolutionWeightsAndBiasesState) -> Bool
    {
        return false
    }
    
    func update(with commandBuffer: MTLCommandBuffer, gradientState: MPSCNNConvolutionGradientState, sourceState: MPSCNNConvolutionWeightsAndBiasesState) -> MPSCNNConvolutionWeightsAndBiasesState?
    {
        //  Create the update rule optimizer if needed
        if (updateOptimizer == nil) {
            let desc = MPSNNOptimizerDescriptor(learningRate: currentLearningRate,
                       gradientRescale: gradientRescale,
                       applyGradientClipping: applyGradientClipping,
                       gradientClipMax: gradientClipMax,
                       gradientClipMin: gradientClipMin,
                       regularizationType: regularizationType,
                       regularizationScale: regularizationScale)
            switch (updateRule) {
            case .SGD:
//                updateOptimizer = MPSNNOptimizerStochasticGradientDescent(device: commandBuffer.device, learningRate: currentLearningRate)
                updateOptimizer = MPSNNOptimizerStochasticGradientDescent(device: commandBuffer.device,
                        momentumScale: momentumScale,
                        useNestrovMomentum: useNesterovMomentum,
                        optimizerDescriptor: desc)
                //  momentumScale 0.0, useNestrovMomentum   false
            case .RMSProp:
//                updateOptimizer = MPSNNOptimizerRMSProp(device: commandBuffer.device, learningRate: currentLearningRate)
                updateOptimizer = MPSNNOptimizerRMSProp(device: commandBuffer.device,
                        decay: beta1,
                        epsilon: epsilon,
                        optimizerDescriptor: desc)

            case .Adam:
//                updateOptimizer = MPSNNOptimizerAdam(device: commandBuffer.device, learningRate: currentLearningRate)
                updateOptimizer = MPSNNOptimizerAdam(device: commandBuffer.device, beta1: beta1, beta2: beta2, epsilon: epsilon, timeStep: timeStep, optimizerDescriptor: desc)
            }
        }
        
        //  Check the weights and bias states
        if (weightsAndBiasState == nil) { return nil }
        
        //  Encode the optimizer
        switch (updateRule) {
        case .SGD:
            if (momentumScale > 0.0 && inputMomentumVectors == nil) {
                inputMomentumVectors = createUpdateVectors(device: commandBuffer.device)
            }
            (updateOptimizer! as! MPSNNOptimizerStochasticGradientDescent).encode(commandBuffer: commandBuffer,
                                   convolutionGradientState: gradientState,
                                   convolutionSourceState: sourceState,
                                   inputMomentumVectors: inputMomentumVectors,
                                   resultState: weightsAndBiasState!)
       case .RMSProp:
            if (inputSumOfSquaresVectors == nil) {
                inputSumOfSquaresVectors = createUpdateVectors(device: commandBuffer.device)
            }
            (updateOptimizer! as! MPSNNOptimizerRMSProp).encode(commandBuffer: commandBuffer,
                                  convolutionGradientState: gradientState,
                                  convolutionSourceState: sourceState,
                                  inputSumOfSquaresVectors: inputSumOfSquaresVectors,
                                      resultState: weightsAndBiasState!)
       case .Adam:
            if (inputMomentumVectors == nil) {
                inputMomentumVectors = createUpdateVectors(device: commandBuffer.device)
            }
            if (inputVelocityVectors == nil) {
                inputVelocityVectors = createUpdateVectors(device: commandBuffer.device)
            }
            (updateOptimizer! as! MPSNNOptimizerAdam).encode(commandBuffer: commandBuffer,
                                convolutionGradientState: gradientState,
                                convolutionSourceState: sourceState,
                                inputMomentumVectors: inputMomentumVectors,
                                inputVelocityVectors: inputVelocityVectors,
                                resultState: weightsAndBiasState!)
       }
        
        return weightsAndBiasState
    }

}

