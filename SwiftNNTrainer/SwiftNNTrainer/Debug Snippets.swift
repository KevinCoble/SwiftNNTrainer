//
//  Debug Snippets.swift
//  SwiftNNTrainer
//
//  Created by Kevin Coble on 3/3/19.
//  Copyright © 2019 Kevin Coble. All rights reserved.
//

import Foundation

//  -- Snippets of code used in the Debug training method for checking things out

//  MARK: - output size

guard let doc = document else { return }
doc.initializeWeights()
let _ = doc.getForwardGraph(commandQueue: commandQueue)!
guard let testingData = doc.getTestingSample(sampleNumber: 0) else {
    return
}
//  Convert the training sample to an input set
let testImage2 = convertInputToImage(metalDevice: metalDevice, dimensions: doc.docData.inputDimensions, inputData: testingData.input)
print("input size = \(testImage2.width)x\(testImage2.height)x\(testImage2.featureChannels)" )

for i in 0..<doc.docData.layers.count {
    let graph3 = MPSNNGraph(device: commandQueue.device, resultImage: doc.docData.layers[i].lastForwardOnlyNode!.resultImage, resultImageIsNeeded: true)!
    
    let commandBuffer = commandQueue.makeCommandBuffer()!
    let outputImage = graph3.encode(to: commandBuffer, sourceImages: [testImage2], sourceStates: nil,
                                    intermediateImages : nil, destinationStates: nil)
    // Syncronize the outputs after the prediction has been made
    // so we can get access to the values on the CPU
    if let image = outputImage {
        image.synchronize(on: commandBuffer)
    }
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    if let image = outputImage {
        print("after layer \(i) = \(image.width)x\(image.height)x\(image.featureChannels)" )
        //                if (doc.docData.layers[i].type == .Convolution) {
        //                    if let weights = doc.docData.layers[i].weightArray {
        //                        print("  Convolutional layer weight size = \(weights.count)")
        //                    }
        //                }
        //                if (i < 6) {
        //                    let features = image.getResultArray()
        //                    print(features)
        //                    var numValid = 0
        //                    var numNan = 0
        //                    for feature in features {
        //                        if (feature.isNaN) {
        //                            numNan += 1
        //                        }
        //                        else {
        //                            numValid += 1
        //                        }
        //                    }
        //                    print("Num valid = \(numValid)")
        //                    print("Num NaN = \(numNan)")
        //                }
    }
}




//  MARK: - multi-layer


//  Create an input set
//        let inputDesc = MPSImageDescriptor(channelFormat: .float32, width: 5, height: 5, featureChannels: 1)
//        inputDesc.storageMode = .managed
//        let testImage = MPSImage(device: metalDevice, imageDescriptor: inputDesc)
let input : [Float] = [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0, 20.0, 21.0, 22.0, 23.0, 24.0
    , 25.0, 26.0, 27.0, 28.0, 29.0, 30.0, 31.0, 32.0, 33.0, 34.0, 35.0
    //                               ,0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0,17.0, 18.0, 19.0, 20.0, 21.0, 22.0, 23.0, 24.0
]
//        testImage.texture.replace(
//            region: MTLRegionMake2D(0, 0, 5, 5),
//            mipmapLevel: 0,
//            slice: 0,
//            withBytes: UnsafeRawPointer(input),
//            bytesPerRow: 5 * MemoryLayout<Float>.size,
//            bytesPerImage: 25 * MemoryLayout<Float>.size
//        )
let testImage = convertInputToImage(metalDevice: metalDevice, dimensions: [6, 6, 1, 1], inputData: input)

//        //  Get the loss labels
let labelData : [Float] = [0, 0, 0, 0, 1, 0, 0, 0, 0, 0] // Load label data
let x = Data(bytes: UnsafeRawPointer(labelData), count: 10 * MemoryLayout<Float>.size)
let labelDesc = MPSCNNLossDataDescriptor(data: x,
                                         layout: .featureChannelsxHeightxWidth,
                                         size: MTLSize(width: 1, height: 1, depth: 10))!


let cnnLabel = MPSCNNLossLabels(device: metalDevice, labelsDescriptor: labelDesc)

//  Create the graph
let inputImage = MPSNNImageNode(handle: nil)

//        let computeNode = MPSNNAdditionNode(leftSource: inputImage, rightSource: inputImage)

//        let computeNode = MPSCNNNeuronSigmoidNode(source: inputImage)
//        let lossDescriptor = MPSCNNLossDescriptor(type: .meanSquaredError, reductionType: .none)
//        let lossNode = MPSCNNLossNode(source: computeNode.resultImage, lossDescriptor: lossDescriptor)
//        let gcn = computeNode.gradientFilter(withSource: lossNode.resultImage)
//
//        let layer = Layer()
//        layer.type = .FullyConnected
//        layer.subType = 1
//        layer.kernelWidth = 5
//        layer.kernelHeight = 5
//        layer.inputChannels = 2
//        layer.numChannels = 3
//        layer.useBiasTerms = true
//        layer.initializeWeights(inputDimensions: [5, 5, 2, 1])
//        let fc = MPSCNNFullyConnectedNode(source: inputImage, weights: layer)
//
//        let layer2 = Layer()
//        layer2.type = .FullyConnected
//        layer2.subType = 1
//        layer2.kernelWidth = 1
//        layer2.kernelHeight = 1
//        layer2.inputChannels = 3
//        layer2.numChannels = 1
//        layer2.useBiasTerms = true
//        layer2.initializeWeights(inputDimensions: [1, 1, 3, 1])
//        let fc2 = MPSCNNFullyConnectedNode(source: fc.resultImage, weights: layer2)
//

let layer = Layer()
layer.type = .Convolution
layer.subType = 1
layer.kernelWidth = 3
layer.kernelHeight = 3
layer.inputChannels = 1
layer.numChannels = 3
layer.XPaddingMethod = .ValidOnly
layer.YPaddingMethod = .ValidOnly
layer.featurePaddingMethod = .ValidOnly
layer.initializeWeightsForTest(inputDimensions: [6, 6, 1, 1])
let conv = MPSCNNConvolutionNode(source: inputImage, weights: layer)
let policy = Padding()
policy.layer = layer
conv.paddingPolicy = policy

let layer2 = Layer()
layer2.type = .Pooling
layer2.subType = 1
layer2.kernelWidth = 2
layer2.kernelHeight = 2
layer2.strideX = 2
layer2.strideY = 2
layer2.inputChannels = 3
layer2.numChannels = 3
layer2.XPaddingMethod = .ValidOnly
layer2.YPaddingMethod = .ValidOnly
layer2.featurePaddingMethod = .ValidOnly
let pool = MPSCNNPoolingMaxNode(source: conv.resultImage, kernelWidth: 2, kernelHeight: 2, strideInPixelsX: 2, strideInPixelsY: 2)
let policy2 = Padding()
policy2.layer = layer2
pool.paddingPolicy = policy2

let layer3 = MPSCNNSoftMaxNode(source: pool.resultImage)

if let graph = MPSNNGraph(device: commandQueue.device,
                          resultImage: layer3.resultImage, resultImageIsNeeded: true) {
    
    //  Continue here
    //            print(graph.debugDescription)
    
    let commandBuffer = commandQueue.makeCommandBuffer()!
    let outputImage = graph.encode(to: commandBuffer, sourceImages: [testImage], sourceStates: [cnnLabel],
                                   intermediateImages : nil, destinationStates: nil)
    // Syncronize the outputs after the prediction has been made
    // so we can get access to the values on the CPU
    if let image = outputImage {
        image.synchronize(on: commandBuffer)
    }
    
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    if let image = outputImage {
        let features = image.getResultArray()
        print(features)
    }
    
    
    
    //            graph.executeAsync(withSourceImages: [testImage]) { outputImage, error in
    //                if let image = outputImage {
    //                    let features = getResultArray()
    //                    print(features)
    //                }
    //            }
    
} else {
    fatalError("Error: could not initialize graph")
}




//  -- Test kernel concatenation

let input1 : [Float] = [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0
    , 0.0, -1.0, -2.0, -3.0, -4.0, -5.0, -6.0, -7.0, -8.0, -9.0, -10.0, -11.0, -12.0, -13.0, -14.0, -15.0
    , -10.0, -11.0, -12.0, -13.0, -14.0, -15.0, -16.0, -17.0, -18.0, -19.0, -20.0, -21.0, -22.0, -23.0, -24.0, -25.0
    , -30.0, -31.0, -32.0, -33.0, -34.0, -35.0, -36.0, -37.0, -38.0, -39.0, -40.0, -41.0, -42.0, -43.0, -44.0, -45.0
    , -50.0, -51.0, -52.0, -53.0, -54.0, -55.0, -56.0, -57.0, -58.0, -59.0, -60.0, -61.0, -62.0, -63.0, -64.0, -65.0
]
let input2 : [Float] = [20.0, 21.0, 22.0, 23.0, 24.0, 25.0, 26.0, 27.0, 28.0, 29.0, 30.0, 31.0, 32.0, 33.0, 34.0, 35.0
]
let input3 : [Float] = [40.0, 41.0, 42.0, 43.0, 44.0, 45.0, 46.0, 47.0, 48.0, 49.0, 50.0, 51.0, 52.0, 53.0, 54.0, 55.0
]

//  Convert to images
let testImage1 = convertInputToImage(metalDevice: metalDevice, dimensions: [4, 4, 5, 1], inputData: input1)
let testImage2 = convertInputToImage(metalDevice: metalDevice, dimensions: [4, 4, 1, 1], inputData: input2)
let testImage3 = convertInputToImage(metalDevice: metalDevice, dimensions: [4, 4, 1, 1], inputData: input3)

//  Get the concatenation node
let inputImage1 = MPSNNImageNode(handle: nil)
let inputImage2 = MPSNNImageNode(handle: nil)
let inputImage3 = MPSNNImageNode(handle: nil)
let concat = MPSNNConcatenationNode(sources: [inputImage1, inputImage2, inputImage3])

//  Create the contraction node
let contractionWeights = ConcatenationContractionWeights(inputChannelSizes : [5, 1, 1])
let contractionPadding = ConcatenationContractionPadding()
let contractionLayer = MPSCNNConvolutionNode(source: concat.resultImage, weights: contractionWeights)
contractionLayer.paddingPolicy = contractionPadding

//  Create the graph
if let graph = MPSNNGraph(device: commandQueue.device,
                          resultImage: contractionLayer.resultImage, resultImageIsNeeded: true) {
    
    //  Encode the data
    let commandBuffer = commandQueue.makeCommandBuffer()!
    let outputImage = graph.encode(to: commandBuffer, sourceImages: [testImage1, testImage2, testImage3], sourceStates: nil,
                                   intermediateImages : nil, destinationStates: nil)
    
    //  Display the output
    if let image = outputImage {
        image.synchronize(on: commandBuffer)
    }
    
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    if let image = outputImage {
        print("after concatenation size = \(image.width)x\(image.height)x\(image.featureChannels)" )
        let features = image.getResultArray()
        print(features)
    }
}


//  -- Test gradient return network

let input : [Float] = [0.0, 1.0]
let testImage = convertInputToImage(metalDevice: metalDevice, dimensions: [2, 1, 1, 1], inputData: input)
testImage.label = "test image"
//  Get the loss labels
let labelData : [Float] = [0.5, 0.5] // Load label data
let x = Data(bytes: UnsafeRawPointer(labelData), count: labelData.count * MemoryLayout<Float>.size)
let labelDesc = MPSCNNLossDataDescriptor(data: x,
                                         layout: .featureChannelsxHeightxWidth,
                                         size: MTLSize(width: 2, height: 1, depth: 1))!
let label = MPSCNNLossLabels(device: metalDevice, labelsDescriptor: labelDesc)
label.label = "loss label"

let inputImage = MPSNNImageNode(handle: nil)
//        let layer = doc.docData.flows[0].layers[0]
let layer = Layer()
layer.type = .FullyConnected
layer.subType = 1
layer.kernelWidth = 2
layer.kernelHeight = 1
layer.inputChannels = 1
layer.numChannels = 1
layer.useBiasTerms = true
layer.initializeWeights(inputDimensions: [2, 1, 1, 1])
let fc = MPSCNNFullyConnectedNode(source: inputImage, weights: layer)
fc.label = "fc layer"
layer.setWeightAndBiasState(device: metalDevice)

let lossDescriptor = MPSCNNLossDescriptor(type: .meanSquaredError, reductionType: .none)
let lossNode = MPSCNNLossNode(source: fc.resultImage, lossDescriptor: lossDescriptor)
lossNode.label = "loss layer"

let gradFC = fc.gradientFilter(withSource: lossNode.resultImage) as! MPSCNNConvolutionGradientNode
gradFC.label = "fc gradient layer"

if let graph = MPSNNGraph(device: commandQueue.device,
                          resultImage: gradFC.resultImage, resultImageIsNeeded: true) {
    let commandBuffer = commandQueue.makeCommandBuffer()!
    
    print(graph.debugDescription)
    
    let outputImage = graph.encodeBatch(to: commandBuffer, sourceImages: [[testImage]], sourceStates: [[label]])
    if let image = outputImage {
        image[0].synchronize(on: commandBuffer)
    }
    
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    if let image = outputImage {
        let features = image[0].getResultArray()
        print(features)
    }
}

//  -- Test split gradient network

let input1 : [Float] = [0.0, 1.0, 2.0, 3.0]
let testImage1 = convertInputToImage(metalDevice: metalDevice, dimensions: [2, 2, 1, 1], inputData: input1)
testImage1.label = "test image 1"

let input2 : [Float] = [4.0, 5.0, 6.0, 7.0]
let testImage2 = convertInputToImage(metalDevice: metalDevice, dimensions: [2, 2, 1, 1], inputData: input2)
testImage2.label = "test image 2"

let labelData : [Float] = [3.0, 7.0, 8.0, 20.0] // Load label data
let x = Data(bytes: UnsafeRawPointer(labelData), count: labelData.count * MemoryLayout<Float>.size)
let labelDesc = MPSCNNLossDataDescriptor(data: x,
                                         layout: .featureChannelsxHeightxWidth,
                                         size: MTLSize(width: 2, height: 2, depth: 1))!
let label = MPSCNNLossLabels(device: metalDevice, labelsDescriptor: labelDesc)
label.label = "loss label"


let inputImage1 = MPSNNImageNode(handle: nil)
let inputImage2 = MPSNNImageNode(handle: nil)

//        let add = MPSNNAdditionNode(leftSource: inputImage1, rightSource: inputImage2)
//            //  result = [4.0, 6.0, 8.0, 10.0]
let multiply = MPSNNMultiplicationNode(leftSource: inputImage1, rightSource: inputImage2)
//  result = [0.0, 5.0, 12.0, 21.0]

let lossDescriptor = MPSCNNLossDescriptor(type: .meanSquaredError, reductionType: .none)
let lossNode = MPSCNNLossNode(source: multiply.resultImage, lossDescriptor: lossDescriptor)
lossNode.label = "loss layer"
//  result = [2.0, -2.0, 0.0, -20.0]  (add)
//  result = [-6.0, -4.0, 8.0, 2.0]   (multiply)

//        let addGrad = add.gradientFilters(withSource: lossNode.resultImage)
//            //  result = [2.0, -2.0, 0.0, -20.0]
let multGrad = multiply.gradientFilters(withSource: lossNode.resultImage)
//  result = [0.0, -4.0, 16.0, 6.0]   (for 0)
//  result = [-24.0, -20.0, 48.0, 14.0]  (for 1)

//        if #available(OSX 10.15, *) {
//            let resultNeeded : [ObjCBool] = [true, true]
//            if let graph = MPSNNGraph(device: commandQueue.device, resultImages: [multGrad[0].resultImage, multGrad[1].resultImage], resultsAreNeeded: UnsafeMutablePointer(mutating: resultNeeded)) {
//            } else {
//                // Fallback on earlier versions
//            }
if let graph = MPSNNGraph(device: commandQueue.device,
                          resultImage: multGrad[1].resultImage, resultImageIsNeeded: true) {
    let commandBuffer = commandQueue.makeCommandBuffer()!
    
    print(graph.debugDescription)
    
    let outputImage = graph.encode(to: commandBuffer, sourceImages: [testImage1, testImage2], sourceStates: [label], intermediateImages: nil, destinationStates: nil)
    //            let outputImage = graph.encode(to: commandBuffer, sourceImages: [testImage1, testImage2])
    //            let outputImage = graph.encodeBatch(to: commandBuffer, sourceImages: [[testImage1, testImage2]], sourceStates: nil)
    if let image = outputImage {
        image.synchronize(on: commandBuffer)
    }
    
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    if let image = outputImage {
        print("output size = \(image.width)x\(image.height)x\(image.featureChannels)" )
        let features = image.getResultArray()
        print(features)
    }
}

//  -- Attempt multi-flow network

let input1 : [Float] = [0.0, 1.0, 2.0, 3.0]
let testImage1 = convertInputToImage(metalDevice: metalDevice, dimensions: [2, 2, 1, 1], inputData: input1)
testImage1.label = "test image 1"

let input2 : [Float] = [4.0, 5.0, 6.0, 7.0]
let testImage2 = convertInputToImage(metalDevice: metalDevice, dimensions: [2, 2, 1, 1], inputData: input2)
testImage2.label = "test image 2"

let labelData : [Float] = [30.0] // Load label data
let x = Data(bytes: UnsafeRawPointer(labelData), count: labelData.count * MemoryLayout<Float>.size)
let labelDesc = MPSCNNLossDataDescriptor(data: x,
                                         layout: .featureChannelsxHeightxWidth,
                                         size: MTLSize(width: 1, height: 1, depth: 1))!
let label = MPSCNNLossLabels(device: metalDevice, labelsDescriptor: labelDesc)
label.label = "loss label"


let inputImage1 = MPSNNImageNode(handle: nil)
let inputImage2 = MPSNNImageNode(handle: nil)

let layer1 = Layer()
layer1.type = .Convolution
layer1.subType = 1
layer1.kernelWidth = 2
layer1.kernelHeight = 2
layer1.inputChannels = 1
layer1.numChannels = 1
layer1.useBiasTerms = false
layer1.initializeWeightsForTest(inputDimensions: [2, 2, 1, 1])
let conv1 = MPSCNNConvolutionNode(source: inputImage1, weights: layer1)
let policy1 = Padding()
policy1.layer = layer1
conv1.paddingPolicy = policy1
conv1.label = "conv1 layer"
layer1.lastNode = conv1
layer1.setWeightAndBiasState(device: metalDevice)           //  Result  [3.0]


let layer2 = Layer()
layer2.type = .Convolution
layer2.subType = 1
layer2.kernelWidth = 2
layer2.kernelHeight = 2
layer2.inputChannels = 1
layer2.numChannels = 1
layer2.useBiasTerms = false
layer2.initializeWeightsForTest(inputDimensions: [2, 2, 1, 1])
let conv2 = MPSCNNConvolutionNode(source: inputImage2, weights: layer2)
let policy2 = Padding()
policy2.layer = layer2
conv2.paddingPolicy = policy2
conv2.label = "conv2 layer"
layer2.lastNode = conv2
layer2.setWeightAndBiasState(device: metalDevice)           //  Result  [11.0]

let multiply = MPSNNMultiplicationNode(leftSource: conv1.resultImage, rightSource: conv2.resultImage)       //  Result [33.0]


let multiplyImage = MPSNNImageNode(handle: nil)

let lossDescriptor = MPSCNNLossDescriptor(type: .meanSquaredError, reductionType: .none)
let lossNode = MPSCNNLossNode(source: multiplyImage, lossDescriptor: lossDescriptor)     //  Result [6.0]
lossNode.label = "loss layer"

let multGrad = multiply.gradientFilters(withSource: lossNode.resultImage)       //  Result [18.0] for 0, [66.0] for 1

let conv1Grad = conv1.gradientFilter(withSource: multGrad[0].resultImage) as! MPSCNNConvolutionGradientNode     //  Result  [9.0, 9.0, 9.0, 9.0]
let conv2Grad = conv2.gradientFilter(withSource: multGrad[1].resultImage) as! MPSCNNConvolutionGradientNode     //  Result [33.0, 33.0, 33.0, 33.0]

//  Create three graphs.
let graph1 = MPSNNGraph(device: commandQueue.device,
                        resultImage: multiply.resultImage, resultImageIsNeeded: true)       //  First one stops at the loss
let graph2 = MPSNNGraph(device: commandQueue.device,
                        resultImage: conv1Grad.resultImage, resultImageIsNeeded: false)       //  Second one goes from loss down to input 1
let graph3 = MPSNNGraph(device: commandQueue.device,
                        resultImage: conv2Grad.resultImage, resultImageIsNeeded: false)       //  Third one goes from loss down to input 2


if (graph1 != nil && graph2 != nil && graph3 != nil) {
    let commandBuffer = commandQueue.makeCommandBuffer()!
    
    if let multiplyImage = graph1!.encode(to: commandBuffer, sourceImages: [testImage1, testImage2]) {
        print("multiplyImage size = \(multiplyImage.width)x\(multiplyImage.height)x\(multiplyImage.featureChannels)" )
        let _ = graph2!.encode(to: commandBuffer, sourceImages: [multiplyImage], sourceStates: [label], intermediateImages: nil, destinationStates: nil)
        let _ = graph3!.encode(to: commandBuffer, sourceImages: [multiplyImage], sourceStates: [label], intermediateImages: nil, destinationStates: nil)
    }
    //            let outputLossImage = graph1!.encode(to: commandBuffer, sourceImages: [testImage1, testImage2], sourceStates: [label], intermediateImages: nil, destinationStates: nil)
    //            commandBuffer.commit()
    //            commandBuffer.waitUntilCompleted()
    //
    //            if let lossImage = outputLossImage {
    //                let commandBuffer2 = commandQueue.makeCommandBuffer()!
    //                graph2!.encode(to: commandBuffer2, sourceImages: [lossImage])
    //                graph3!.encode(to: commandBuffer2, sourceImages: [lossImage])
    //
    //                image.synchronize(on: commandBuffer)
    //            }
    
    //            commandBuffer.commit()
    //            commandBuffer.waitUntilCompleted()
    //            if let image = outputImage {
    //                print("output size = \(image.width)x\(image.height)x\(image.featureChannels)" )
    //                let features = image.getResultArray()
    //                print(features)
    //            }
}
