//
//  MLModel.swift
//  SwiftNNTrainer
//
//  Created by Kevin Coble on 3/25/19.
//  Copyright © 2019 Kevin Coble. All rights reserved.
//

import Foundation

enum MLModelImportError: Error {
    case moreThanOneInput
    case unsupportedInputFeatureType
    case unsupportedOutputFeatureType
    case unsupportedModelType
    case layerInputNotFound
    case errorParsingModel

    func getAlertString() -> String
    {
        switch (self) {
        case .moreThanOneInput:
            return "More than one input found in MLModel.  Only one input an be in imported model"
        case .unsupportedInputFeatureType:
            return "The input feature type of the imported MLModel is not supported"
        case .unsupportedOutputFeatureType:
            return "The output feature type of the imported MLModel is not supported"
        case .unsupportedModelType:
            return "The model type of the MLModel is not supported.  Only Network models (classifier or regressor) are allowed"
        case .layerInputNotFound:
            return "The input with the required identifier for on of the model layers could not be found"
        case .errorParsingModel:
            return "Unknown error parsing the model"
        }
    }
}


enum MLModelExportError: Error {
    case errorCreatingModel
    case errorWritingModel
    case unsupportedLayerType
    case paddingDifferentBetweenDimensions
    case unsupportedActivationType

    func getAlertString() -> String
    {
        switch (self) {
        case .errorCreatingModel:
            return "Error createing the MLModel file from the objects"
        case .errorWritingModel:
            return "Error writing the specified MLModel file"
        case .unsupportedLayerType:
            return "The SwiftNNTrainer model contains one or more layers that are not supported for export"
        case .paddingDifferentBetweenDimensions:
            return "The SwiftNNTrainer model contains a layer with different padding directives for different dimensions"
        case .unsupportedActivationType:
            return "The SwiftNNTrainer model contains a Neuron layer with an unsupported activagtion type"
        }
    }
}


extension Document
{
    //  Create a document from an MLModel
    convenience init(model : CoreML_Specification_Model) throws
    {
        self.init()
        
        //  Get the model description
        let description = model.description_p
        
        //  Get the input size from model
        let inputs = description.input
        if (inputs.count != 1) {
            throw MLModelImportError.moreThanOneInput
        }
        if (inputs[0].hasType) {
            switch (inputs[0].type.type!) {
            case .multiArrayType(let arrayFeatureType):
                let shape = arrayFeatureType.shape
                if (shape.count == 3) {
                    docData.inputDimensions[0] = Int(shape[2])
                    docData.inputDimensions[1] = Int(shape[1])
                    docData.inputDimensions[2] = Int(shape[0])
                    docData.inputDimensions[3] = 1
                }
                else {
                    docData.inputDimensions[2] = Int(shape[0])
                    docData.inputDimensions[0] = 1
                    docData.inputDimensions[1] = 1
                    docData.inputDimensions[3] = 1
                }
            case .imageType(let imageFeatureType):
                docData.inputDimensions[0] = Int(imageFeatureType.width)
                docData.inputDimensions[1] = Int(imageFeatureType.height)
                switch (imageFeatureType.colorSpace) {
                case .bgr, .rgb:
                    docData.inputDimensions[2] = 3
                case .grayscale:
                    docData.inputDimensions[2] = 1
                default:
                    throw MLModelImportError.unsupportedInputFeatureType
                }
            default:
                throw MLModelImportError.unsupportedInputFeatureType
            }
        }
        
        //  Check the model type and get the layers
        let type = model.type!
        var layers : [CoreML_Specification_NeuralNetworkLayer]
        switch (type) {
        case .neuralNetworkRegressor(let regressor):
            docData.outputType = .Regression
            layers = regressor.layers
        case .neuralNetworkClassifier(let classifier):
            docData.outputType = .Classification
            layers = classifier.layers
            //  Load the labels
            if let labelType = classifier.classLabels {
                switch (labelType) {
                case .int64ClassLabels(let intLabels):
                    //  See if the labels are in order
                    var inOrder = true
                    for i in 0..<intLabels.vector.count {
                        if (intLabels.vector[i] != Int64(i)) {
                            inOrder = false
                            break
                        }
                    }
                    //  If not in order, make a string version of the labels
                    if (!inOrder) {
                        docData.labels = []
                        for label in intLabels.vector {
                            docData.labels!.append("\(label)")
                        }
                    }
                case .stringClassLabels(let stringLabels):
                    docData.labels = []
                    for label in stringLabels.vector {
                        docData.labels!.append(label)
                    }
                }
            }
        case .neuralNetwork(let network):
            docData.outputType = .Regression
            layers = network.layers
        default:
            throw MLModelImportError.unsupportedModelType
        }
        
        // Pick network output if more than one
        let outputs = description.output
        var outputIndex = 0
        if (outputs.count > 1) {
            //  If a classification problem, look for the dictionary
            if (docData.outputType == .Classification) {
                for index in 0..<outputs.count {
                    if (outputs[index].hasType) {
                        switch (outputs[index].type.type!) {
                        case .dictionaryType:
                            outputIndex = index
                        default:
                            continue
                        }
                    }
                }
            }
            //  If a regression problem, look for the array
            else {
                for index in 0..<outputs.count {
                    if (outputs[index].hasType) {
                        switch (outputs[index].type.type!) {
                        case .multiArrayType:
                            outputIndex = index
                        default:
                            continue
                        }
                    }
                }
            }
        }
        
        //  Get the output size from model
        var mustGetOutputSizeFromNetwork = false
        if (outputs[outputIndex].hasType) {
            switch (outputs[outputIndex].type.type!) {
            case .multiArrayType(let arrayFeatureType):
                let shape = arrayFeatureType.shape
                if (shape.count == 3) {
                    docData.outputDimensions[0] = Int(shape[2])
                    docData.outputDimensions[1] = Int(shape[1])
                    docData.outputDimensions[2] = Int(shape[0])
                    docData.outputDimensions[3] = 1
                }
                else {
                    docData.outputDimensions[2] = Int(shape[0])
                    docData.outputDimensions[0] = 1
                    docData.outputDimensions[1] = 1
                    docData.outputDimensions[3] = 1
                }
            case .doubleType, .int64Type:
                docData.outputDimensions[2] = 1
                docData.outputDimensions[0] = 1
                docData.outputDimensions[1] = 1
                docData.outputDimensions[3] = 1
            case .dictionaryType:
                docData.outputDimensions[2] = 100
                docData.outputDimensions[0] = 1
                docData.outputDimensions[1] = 1
                docData.outputDimensions[3] = 1
                //  Must get dimensions from feeding layer
                mustGetOutputSizeFromNetwork = true
            default:
                throw MLModelImportError.unsupportedOutputFeatureType
            }
        }
        //  Find the number of inputs and number of references to outputs so we can organize flows
        var numInputs = [Int](repeating: 0, count: layers.count)
        var numOutputReferences = [Int](repeating: 0, count: layers.count)
        for index in 0..<layers.count {
            numInputs[index] = layers[index].input.count
            for out in layers[index].output {
                for layer in layers {
                    for i in layer.input {
                        if (i == out) { numOutputReferences[index] += 1 }
                    }
                }
            }
        }
        
        //  Count the number of flows we will need
        var numFlows = 0
        for index in 0..<layers.count {
            if (numInputs[index] > 1) { numFlows += 1 }
            if (numOutputReferences[index] > 1) { numFlows += numOutputReferences[index] }
            if (numOutputReferences[index] == 0) { numFlows += 1 }  //  Output flow
        }
        
        //  If more than 1 flow, create the additional ones
        if (numFlows > 1) {
            for _ in 1..<numFlows {
                let newFlow = Flow()
                docData.flows.append(newFlow)
            }
        }
        
        //  Set up an array for the current data name for each flow, and the number of flow output references for the current data
        var currentDataForFlow = [String](repeating: "", count: numFlows)
        var outputReferencesForFlow = [Int](repeating: 0, count: numFlows)

        //  Set the initial flow data to be the input name
        currentDataForFlow[0] = inputs[0].name
        outputReferencesForFlow[0] = 1

        //  Process the layers
        for index in 0..<layers.count {
            //  If this is a 'concat' layer that has multiple inputs, start a new flow with the inputs and set the output name
            let layerType = layers[index].layer!
            switch (layerType) {        //  Can't get the compiler to allow an 'if'
            case .concat:
                if let newFlowIndex = currentDataForFlow.firstIndex(of: "") {
                    for input in layers[index].input {
                        if let inputFlowIndex = currentDataForFlow.firstIndex(of: input) {
                            docData.flows[newFlowIndex].inputs.append(InputSource(type: .Flow, index: inputFlowIndex))
                        }
                        else {
                            throw MLModelImportError.errorParsingModel
                        }
                    }
                    outputReferencesForFlow[newFlowIndex] = numOutputReferences[index]
                    currentDataForFlow[newFlowIndex] = layers[index].output[0]
                }
                else {
                    throw MLModelImportError.errorParsingModel
                }
                continue
            case .flatten:      //  Ignore flatten layers (if not ChannelFirst, we might have to do something)
                if let flowIndex = currentDataForFlow.firstIndex(of: layers[index].input[0]) {
                    currentDataForFlow[flowIndex] = layers[index].output[0]
               }
                continue
            default: ()
            }


            //  Find the flow that has the input
            if let flowIndex = currentDataForFlow.firstIndex(of: layers[index].input[0]) {
                //  If that flow has multiple output references, start a new flow
                if (outputReferencesForFlow[flowIndex] > 1) {
                    if let newFlowIndex = currentDataForFlow.firstIndex(of: "") {
                        if let newLayer = try Layer(layers[index]) {
                            docData.flows[newFlowIndex].layers.append(newLayer)
                            outputReferencesForFlow[newFlowIndex] = numOutputReferences[index]
                            currentDataForFlow[newFlowIndex] = layers[index].output[0]
                            docData.flows[newFlowIndex].inputs.append(InputSource(type: .Flow, index: flowIndex))
                        }
                    }
                    else {
                        throw MLModelImportError.errorParsingModel
                    }
                }
                else {
                    if let newLayer = try Layer(layers[index]) {
                        docData.flows[flowIndex].layers.append(newLayer)
                        outputReferencesForFlow[flowIndex] = numOutputReferences[index]
                        currentDataForFlow[flowIndex] = layers[index].output[0]
                    }
                }
            }
            else {
                throw MLModelImportError.layerInputNotFound
            }
        }
        
        //  Find the flow that has the output name
        if (numFlows > 0) {
            if let outFlowIndex = currentDataForFlow.firstIndex(of: outputs[0].name) {
                docData.outputFlow = outFlowIndex
            }
        }
        
        //  Update the flow sizes
        docData.updateFlowDimensions()
        docData.setSizeDependentParameters()
        
        //  Transpose weight matrices (need input sizes, so must wait till now)
        transposeMLModelWeights()
        
        //  If we couldn't get the output size from the description, get it from the network
        if (mustGetOutputSizeFromNetwork) {
            docData.outputDimensions = docData.flows[docData.outputFlow].currentOutputSize
       }

        //  Start with not needing weight initialization
        docData.needsWeightInitialization = false;

        //  Validate the network
        validateNetwork()
    }
    
    //  Export the model to an MLModel file
    func exportMLModel(url : URL, imageInput : Bool) throws {
        //  Create the input feature description
        var featureType = CoreML_Specification_FeatureType()
        if (imageInput) {
            featureType.imageType = CoreML_Specification_ImageFeatureType()
            featureType.imageType.width = Int64(docData.inputDimensions[0])
            featureType.imageType.height = Int64(docData.inputDimensions[1])
            if (docData.inputDimensions[2] == 3) {
                featureType.imageType.colorSpace = .rgb
            }
            else {
                featureType.imageType.colorSpace = .grayscale
            }
        }
        else {
            featureType.multiArrayType = CoreML_Specification_ArrayFeatureType()
            featureType.multiArrayType.dataType = .float32
            featureType.multiArrayType.shape = [Int64(docData.inputDimensions[2] * docData.inputDimensions[3]),
                                                Int64(docData.inputDimensions[1]), Int64(docData.inputDimensions[0])]        //  [C] or , [C, H, W]
        }
        var inputFeatureDesc = CoreML_Specification_FeatureDescription()
        inputFeatureDesc.name = "input"
        inputFeatureDesc.shortDescription = "input to neural network"
        inputFeatureDesc.type = featureType
        
        //  Create the output feature description
        var outFeatureType = CoreML_Specification_FeatureType()
        var outputFeatureDesc = CoreML_Specification_FeatureDescription()
        outputFeatureDesc.name = "output"
        if (docData.outputType == .Classification) {
            outputFeatureDesc.shortDescription = "probability for each class"
            var dictFeature = CoreML_Specification_DictionaryFeatureType()
            if (docData.labels == nil) {
                dictFeature.int64KeyType = CoreML_Specification_Int64FeatureType()
            }
            else {
                dictFeature.stringKeyType = CoreML_Specification_StringFeatureType()
            }
            outFeatureType.dictionaryType = dictFeature
        }
        else {
            outputFeatureDesc.shortDescription = "regression output from neural network"
            outFeatureType.multiArrayType = CoreML_Specification_ArrayFeatureType()
            outFeatureType.multiArrayType.dataType = .float32
            if (docData.outputDimensions[0] != 1 || docData.outputDimensions[1] != 1) {
                outFeatureType.multiArrayType.shape = [Int64(docData.outputDimensions[2] * docData.outputDimensions[3]),
                                                       Int64(docData.outputDimensions[1]), Int64(docData.outputDimensions[0])]        //  [C, H, W]
            }
            else {
                outFeatureType.multiArrayType.shape = [Int64(docData.outputDimensions[2] * docData.outputDimensions[3])]        //  [C]
            }
        }
        outputFeatureDesc.type = outFeatureType
        
        //  Create the label feature description
        var labelFeatureDesc = CoreML_Specification_FeatureDescription()
        if (docData.outputType == .Classification) {
            var labelFeatureType = CoreML_Specification_FeatureType()
            if (docData.labels == nil) {
                labelFeatureType.int64Type = CoreML_Specification_Int64FeatureType()
            }
            else {
                labelFeatureType.stringType = CoreML_Specification_StringFeatureType()
            }
            labelFeatureDesc.name = "label"
            labelFeatureDesc.shortDescription = "resulting label"
            labelFeatureDesc.type = labelFeatureType
        }
        
        //  Create the model description
        var modelDesc = CoreML_Specification_ModelDescription()
        modelDesc.input = [inputFeatureDesc]
        if (docData.outputType == .Classification) {
            modelDesc.output = [outputFeatureDesc, labelFeatureDesc]
            modelDesc.predictedFeatureName = "label"
        }
        else {
            modelDesc.output = [outputFeatureDesc]
            modelDesc.predictedFeatureName = "output"
        }
        modelDesc.predictedProbabilitiesName = "output"
        
        //  Create both network types
        var regressor = CoreML_Specification_NeuralNetworkRegressor()
        var classifier = CoreML_Specification_NeuralNetworkClassifier()

        //  Create the classifier labels
        if (docData.outputType == .Classification) {
            if let labels = docData.labels {
                var modelLabels = CoreML_Specification_StringVector()
                modelLabels.vector = labels
                classifier.stringClassLabels = modelLabels
            }
            else {
                var modelLabels = CoreML_Specification_Int64Vector()
                modelLabels.vector = []
                let numOutputs = docData.outputDimensions.reduce(1, *)
                for i in 0..<numOutputs {
                    modelLabels.vector.append(Int64(i))
                }
                classifier.int64ClassLabels = modelLabels
            }
        }
        
        //  Add each layer of each flow
        for flowIndex in 0..<docData.flows.count {
            let flow = docData.flows[flowIndex]
            
            //  Get the input for the flow
            var flowInput : [String] = []
            for input in flow.inputs {
                if (input.type == .Flow) {
                    flowInput.append("flow_\(input.index)_output")
                }
                else {
                    flowInput.append("input")
                }
            }
            
            //  Get each layer
            var inputDimensions = flow.currentInputSize
            for layerIndex in 0..<flow.layers.count {
                //  Get any required output name
                var outputName : String?
                if (layerIndex == flow.layers.count-1) {
                    if (flowIndex == docData.outputFlow) {
                        outputName = "output"     //  Output flow
                    }
                    else {
                        outputName = "flow_\(flowIndex)_output"       //  Some non-output flow
                    }
                }

                //  Get the layer
                let mlLayers = try flow.layers[layerIndex].getMLModelLayers(inputName: flowInput, inputSize: inputDimensions, flowIndex: flowIndex, layerIndex : layerIndex, outputName : outputName)
                
                //  Add the layers to the model
                if (docData.outputType == .Classification) {
                    for layer in mlLayers {
                        classifier.layers.append(layer)
                        flowInput = layer.output
                    }
                }
                else {
                    for layer in mlLayers {
                        regressor.layers.append(layer)
                        flowInput = layer.output
                    }
                }
                
                //  Update the input dimensions
                inputDimensions = flow.layers[layerIndex].getOutputDimensionGivenInput(dimensions: inputDimensions)
            }
        }
        
        //  Create an MLModel
        var model = CoreML_Specification_Model()
        model.specificationVersion = 1
        model.description_p = modelDesc
        if (docData.outputType == .Classification) {
            model.neuralNetworkClassifier = classifier
        }
        else {
            model.neuralNetworkRegressor = regressor
        }
        
        //  Convert the model to data
        var data : Data
        do {
            data = try model.serializedData()
        }
        catch {
            throw MLModelExportError.errorCreatingModel
        }
        
        //  Write the model
         do {
            try data.write(to: url)
        }
        catch {
            throw MLModelExportError.errorWritingModel
        }
    }
    
    func transposeMLModelWeights()
    {
        for flow in docData.flows {
            flow.transposeMLModelWeights()
        }
    }

}


enum MLLayerImportError: Error {
    case unsupportedLayerType
}


extension Flow
{
    func transposeMLModelWeights()
    {
        var dimensions = currentInputSize
        for layer in layers {
            layer.transposeMLModelWeights(dimensions)
            dimensions = layer.getOutputDimensionGivenInput(dimensions: dimensions)
        }
    }
}


extension Layer
{
    //  Create a layer from a MLModel layer
    convenience init?(_ mlLayer : CoreML_Specification_NeuralNetworkLayer) throws
    {
        self.init()
        
        //  Set the name
        layerName = mlLayer.name
        
        //  Switch based on the layer type
        let type = mlLayer.layer!
        switch (type) {
        case .innerProduct(let innerProductParams):
            setFromInnerProduct(innerProductParams)
        case .convolution(let convolutionParams):
            setFromConvolution(convolutionParams)
        case .pooling(let poolingParams):
            setFromPooling(poolingParams)
        case .activation(let activationParams):
            setFromActivation(activationParams)
        case .softmax(let softMaxParams):
            setFromSoftMax(softMaxParams)
        case .lrn(let lrnParams):
            setFromLRN(lrnParams)
        case .flatten:
            return nil   //      No need for flatten layers
        default:
            throw MLLayerImportError.unsupportedLayerType
        }
    }
    
    //  Create an 'inner product' layer
    func setFromInnerProduct(_ params: CoreML_Specification_InnerProductLayerParams)
    {
        //  Set the type
        type = .FullyConnected
        subType = FullyConnectedSubType.NormalWeights.rawValue
        
        //  Set the output channels
        numChannels = Int(params.outputChannels)
        
        //  Set the 'use bias' term
        useBiasTerms = params.hasBias
        
        //  Set the weights
        if (params.hasWeights) {
            setWeightsFromParams(params.weights)
        }
        
        //  If there are bias terms, set those
        if (useBiasTerms) {
            setBiasesFromParams(params.bias)
        }
    }
    
    //  Create a convolution layer
    func setFromConvolution(_ params: CoreML_Specification_ConvolutionLayerParams)
    {
        //  Set the type
        type = .Convolution
        subType = ConvolutionSubType.Normal.rawValue
        
        //  Set the output channels
        numChannels = Int(params.outputChannels)
        
        //!!  check kernelChannels and groups
        
        //  Set the kernel size
        kernelWidth = Int(params.kernelSize[1])
        kernelHeight = Int(params.kernelSize[0])
        
        //  Set the stride
        strideX = Int(params.stride[1])
        strideY = Int(params.stride[0])
        
        //!!  dilation factor
        
        //  Padding
        let paddingType = params.convolutionPaddingType!
        switch (paddingType) {
        case .same:
            XPaddingMethod = .SizeSame
            YPaddingMethod = .SizeSame
            featurePaddingMethod = .SizeSame
        case .valid(let validPadding):
            if (validPadding.hasPaddingAmounts) {
                let borderAmounts = validPadding.paddingAmounts.borderAmounts
                let topPadding =  borderAmounts[0].startEdgeSize
                let bottomPadding =  borderAmounts[0].endEdgeSize
                let leftPadding =  borderAmounts[1].startEdgeSize
                let rightPadding =  borderAmounts[1].endEdgeSize
                //!!  look for custom padding
                if (leftPadding == ((kernelWidth - 1) / 2) && rightPadding == ((kernelWidth - 1) / 2)) {
                    XPaddingMethod = .SizeSame
                }
                else {
                    XPaddingMethod = .ValidOnly
                }
                if (topPadding == ((kernelHeight - 1) / 2) && bottomPadding == ((kernelHeight - 1) / 2)) {
                    YPaddingMethod = .SizeSame
                }
                else {
                    YPaddingMethod = .ValidOnly
                }
                featurePaddingMethod = .ValidOnly
            }
            else {
                XPaddingMethod = .ValidOnly
                YPaddingMethod = .ValidOnly
                featurePaddingMethod = .ValidOnly
            }
        }
        
        //!!  Deconvolution
        
        //  Set the 'use bias' term
        useBiasTerms = params.hasBias
        
        //  Set the weights
        if (params.hasWeights) {
            setWeightsFromParams(params.weights)
        }
        
        //  If there are bias terms, set those
        if (useBiasTerms) {
            setBiasesFromParams(params.bias)
        }
    }
    
    //  Create a pooling layer
    func setFromPooling(_ params: CoreML_Specification_PoolingLayerParams)
    {
        //  Set the type
        type = .Pooling
        
        //  Set the subtype
        let paramType = params.type
        switch (paramType) {
        case .average:
            subType = PoolingSubType.Average.rawValue
        case .l2:
            subType = PoolingSubType.L2Norm.rawValue
        case .max:
            subType = PoolingSubType.Max.rawValue
        default:
            subType = PoolingSubType.Max.rawValue
        }
        
        //  Set the kernel size
        kernelWidth = Int(params.kernelSize[1])
        kernelHeight = Int(params.kernelSize[0])
        
        //  Set the stride
        strideX = Int(params.stride[1])
        strideY = Int(params.stride[0])
        
        //  Padding
        let paddingType = params.poolingPaddingType!
        switch (paddingType) {
        case .same:
            //!! May need to look at padding amounts
            XPaddingMethod = .SizeSame
            YPaddingMethod = .SizeSame
            featurePaddingMethod = .SizeSame
        case .valid:
            XPaddingMethod = .ValidOnly
            YPaddingMethod = .ValidOnly
            featurePaddingMethod = .ValidOnly
        case .includeLastPixel(let padding):
            //   Fudged for googlenet import - this padding would have to be custom set based on input/kernel size
            if (padding.paddingAmounts[0] > 0 || strideX > 1) {
                YPaddingMethod = .SizeSame
                XPaddingMethod = .SizeSame
            }
            else {
                YPaddingMethod = .ValidOnly
                XPaddingMethod = .ValidOnly
            }
            featurePaddingMethod = XPaddingMethod
        }

    }
    
    //  Create a softmax layer
    func setFromSoftMax(_ params: CoreML_Specification_SoftmaxLayerParams)
    {
        //  Set the type
        type = .SoftMax
    }
    
    func setFromLRN(_ params: CoreML_Specification_LRNLayerParams)
    {
        type = .Normalization
        subType = NormalizationSubType.CrossCannel.rawValue
        additionalData[0] = Float(params.localSize)
        additionalData[1] = params.alpha
        additionalData[2] = params.beta
    }

    //  Create an activation layer
    func setFromActivation(_ params: CoreML_Specification_ActivationParams)
    {
        //  Set the type
        type = .Neuron
        
        //  Get the subtype
        let activationType = params.nonlinearityType!
        switch (activationType) {
        case .linear(let activationLinearParams):
            subType = NeuronSubType.Linear.rawValue
            additionalData[0] = activationLinearParams.alpha
            additionalData[1] = activationLinearParams.beta
        case .reLu:
            subType = NeuronSubType.ReLU.rawValue
        case .leakyReLu(let activationLeakyReLUParams):
            subType = NeuronSubType.ReLU.rawValue
            additionalData[0] = activationLeakyReLUParams.alpha
        case .thresholdedReLu:
            subType = NeuronSubType.ReLU.rawValue
            //!!  No thresholding - maybe check for threshold != 0
        case .preLu(let activationPReLUParams):
            subType = NeuronSubType.PReLU.rawValue
            if (activationPReLUParams.hasAlpha) {
                //!!  get parameters
            }
        case .tanh:
            subType = NeuronSubType.TanH.rawValue
            additionalData[0] = 1.0
            additionalData[1] = 1.0
        case .scaledTanh(let activationTanHParams):
            subType = NeuronSubType.TanH.rawValue
            additionalData[0] = activationTanHParams.alpha
            additionalData[1] = activationTanHParams.beta
        case .sigmoid:
            subType = NeuronSubType.Sigmoid.rawValue
        case .sigmoidHard(let activationSigmoidHardParams):
            subType = NeuronSubType.HardSigmoid.rawValue
            additionalData[0] = activationSigmoidHardParams.alpha
            additionalData[1] = activationSigmoidHardParams.beta
        case .elu(let activationELUParams):
            subType = NeuronSubType.ELU.rawValue
            additionalData[0] = activationELUParams.alpha
        case .softsign:
            subType = NeuronSubType.SoftSign.rawValue
        case .softplus:
            subType = NeuronSubType.SoftPlus.rawValue
        case .parametricSoftplus(let activationParametricSoftplusParams):
            subType = NeuronSubType.SoftPlus.rawValue
            if (activationParametricSoftplusParams.hasAlpha) {
                //!!  get parameters
            }
        }
    }
    
    func setWeightsFromParams(_ weightParams : CoreML_Specification_WeightParams)
    {
        weightArray = weightParams.floatValue
    }
    
    func setBiasesFromParams(_ weightParams : CoreML_Specification_WeightParams)
    {
        biases = weightParams.floatValue
    }
    
    func getMLModelLayers(inputName: [String], inputSize : [Int], flowIndex: Int, layerIndex : Int, outputName : String?) throws  -> [CoreML_Specification_NeuralNetworkLayer]
    {
        //  Create the return layer array
        var layers : [CoreML_Specification_NeuralNetworkLayer] = []
        
        //  Create the main layer we will be adding
        var layer = CoreML_Specification_NeuralNetworkLayer()
        
        //  Set the layer name
        if let name = layerName {
            layer.name = name
        }
        else {
            layer.name = generateLayerName(flowIndex: flowIndex, layerIndex : layerIndex)
        }
        
        //  Start any input chain with the current input
        var currentInput = inputName

        //  Fill in based on the type of layer
        switch (type) {
        case .Arithmetic, .UpSampling, .DropOut:
            throw MLModelExportError.unsupportedLayerType
        case .Convolution:
            var convParams = CoreML_Specification_ConvolutionLayerParams()
            convParams.outputChannels = UInt64(numChannels)   //  Set the output channels
            convParams.kernelSize = [UInt64(kernelHeight), UInt64(kernelWidth)]  //  Set the kernel size
            convParams.kernelChannels = UInt64(inputSize[2] * inputSize[3])
            convParams.nGroups = UInt64(1)
            convParams.stride = [UInt64(strideY), UInt64(strideX)]  //  Set the stride
            convParams.convolutionPaddingType = try getConvolutionalPadding(inputSize: inputSize)
            var weights = CoreML_Specification_WeightParams()
            weights.floatValue = transposedConvolutionalWeightArray(inputSize: inputSize)
            convParams.weights = weights
            var bias = CoreML_Specification_WeightParams()
            if (useBiasTerms) {
                bias.floatValue = biases!
                convParams.bias = bias
                convParams.hasBias_p = true
            }
            layer.convolution = convParams
        case .Pooling:
            var poolParams = CoreML_Specification_PoolingLayerParams()
            let poolType = PoolingSubType(rawValue: subType)!
            switch (poolType) {
            case .Average:
                poolParams.type = .average
            case .L2Norm:
                poolParams.type = .l2
            case .Max, .DilatedMax:
                poolParams.type = .max
            }
            poolParams.kernelSize = [UInt64(kernelHeight), UInt64(kernelWidth)]  //  Set the kernel size
            poolParams.stride = [UInt64(strideY), UInt64(strideX)]  //  Set the stride
            poolParams.poolingPaddingType = try getPoolingPadding(inputSize: inputSize)
            layer.pooling = poolParams
        case .FullyConnected:
            if (inputSize[0] != 1 || inputSize[1] != 1) {
                //  Need to add flatten layer to convert to [C * H * W, 1, 1] for the InnerProduct Layer
                var flattenLayer = CoreML_Specification_NeuralNetworkLayer()
                flattenLayer.flatten = CoreML_Specification_FlattenLayerParams()
                flattenLayer.name = layer.name + "_flatten"
                flattenLayer.input = currentInput
                flattenLayer.output = [flattenLayer.name + "_output"]
                currentInput = flattenLayer.output
                layers.append(flattenLayer)
            }
            var fcParams = CoreML_Specification_InnerProductLayerParams()
            fcParams.inputChannels = UInt64(inputSize.reduce(1, *))
            fcParams.outputChannels = UInt64(numChannels)
            var weights = CoreML_Specification_WeightParams()
            weights.floatValue = transposedFullyConnectedWeightArray(inputSize: inputSize)
            fcParams.weights = weights
            var bias = CoreML_Specification_WeightParams()
            if (useBiasTerms) {
                bias.floatValue = biases!
                fcParams.bias = bias
                fcParams.hasBias_p = true
            }
            layer.innerProduct = fcParams
        case .Neuron:
            var activateParams = CoreML_Specification_ActivationParams()
            activateParams.nonlinearityType = try getActivationNonLinearity()
            layer.activation = activateParams
        case .SoftMax:
            let softmaxParams = CoreML_Specification_SoftmaxLayerParams()
            layer.softmax = softmaxParams
        case .Normalization:
            let normType = NormalizationSubType(rawValue: subType)!
            if (normType != .CrossCannel) { throw MLModelExportError.unsupportedLayerType }
            var normalizationParams = CoreML_Specification_LRNLayerParams()
            normalizationParams.localSize = UInt64(additionalData[0])
            normalizationParams.alpha = additionalData[1]
            normalizationParams.beta = additionalData[2]
            layer.lrn = normalizationParams
        }
        
        //  Set the layer input
        layer.input = currentInput

        //  Set the layer output
        if let out = outputName {
            //  Required output name
            layer.output = [out]
        }
        else {
            //  Generated output name
            layer.output = [layer.name + "_output"]
        }
        
        //  Append the required layer
        layers.append(layer)

        //  Return the layer
        return layers
    }
    
    func transposedConvolutionalWeightArray(inputSize: [Int]) -> [Float]
    {
        //  Transpose weight array for MLModel.  MPSCNN uses [Cout, H, W, Cin],  MLModel uses [Cout, Cin, H, W]
        
        //  If Cin is 1, the weight array is fine as is
        let Cin = inputSize[2] * inputSize[3]
        if (Cin == 1) { return weightArray! }
        
        //  Create a transposed matrix
        var transposedWeights = [Float](repeating: 0.0, count: weightArray!.count)
        var index = 0
        let singleKernelSize = kernelHeight * kernelWidth
        for outChannel in 0..<numChannels {
            let destCoutStart = outChannel * Cin * singleKernelSize
            for y in 0..<kernelHeight {
                for x in 0..<kernelWidth {
                    for inChannel in 0..<Cin {
                        let destIndex = destCoutStart + inChannel * singleKernelSize + y * kernelWidth + x
                        transposedWeights[destIndex] = weightArray![index]
                        index += 1
                    }
                }
            }
        }
        
        return transposedWeights
    }
    
    func getConvolutionalPadding(inputSize: [Int]) throws -> CoreML_Specification_ConvolutionLayerParams.OneOf_ConvolutionPaddingType
    {
        //  Verify the padding types are the same for all dimensions
        if (XPaddingMethod != YPaddingMethod) { throw MLModelExportError.paddingDifferentBetweenDimensions }
        
        switch (XPaddingMethod) {
        case .ValidOnly:
            let validPadding = CoreML_Specification_ValidPadding()
            return .valid(validPadding)
        case .SizeSame:
            let samePadding = CoreML_Specification_SamePadding()
            return .same(samePadding)
        case .SizeFull:
            var validPadding = CoreML_Specification_ValidPadding()
            var borderAmounts = CoreML_Specification_BorderAmounts()
            var leftRightBorderAmounts = CoreML_Specification_BorderAmounts.EdgeSizes()
            leftRightBorderAmounts.startEdgeSize = UInt64((kernelWidth - 1) / 2)
            leftRightBorderAmounts.endEdgeSize = UInt64((kernelWidth - 1) / 2)
            var topBottomBorderAmounts = CoreML_Specification_BorderAmounts.EdgeSizes()
            topBottomBorderAmounts.startEdgeSize = UInt64((kernelHeight - 1) / 2)
            topBottomBorderAmounts.endEdgeSize = UInt64((kernelHeight - 1) / 2)
            borderAmounts.borderAmounts = [topBottomBorderAmounts, leftRightBorderAmounts]
            validPadding.paddingAmounts = borderAmounts
            return .valid(validPadding)
        case .Custom:
            var validPadding = CoreML_Specification_ValidPadding()
            var borderAmounts = CoreML_Specification_BorderAmounts()
            var leftRightBorderAmounts = CoreML_Specification_BorderAmounts.EdgeSizes()
            leftRightBorderAmounts.startEdgeSize = UInt64(XOffset)
            leftRightBorderAmounts.endEdgeSize = UInt64(clipWidth - inputSize[0])
            var topBottomBorderAmounts = CoreML_Specification_BorderAmounts.EdgeSizes()
            topBottomBorderAmounts.startEdgeSize = UInt64(YOffset)
            topBottomBorderAmounts.endEdgeSize = UInt64(clipHeight - inputSize[1])
            borderAmounts.borderAmounts = [topBottomBorderAmounts, leftRightBorderAmounts]
            validPadding.paddingAmounts = borderAmounts
            return .valid(validPadding)
        }
    }
    
    func getPoolingPadding(inputSize: [Int]) throws -> CoreML_Specification_PoolingLayerParams.OneOf_PoolingPaddingType
    {
        //  Verify the padding types are the same for all dimensions
        if (XPaddingMethod != YPaddingMethod) { throw MLModelExportError.paddingDifferentBetweenDimensions }
        
        switch (XPaddingMethod) {
        case .ValidOnly:
            let validPadding = CoreML_Specification_ValidPadding()
            return .valid(validPadding)
        case .SizeSame:
            let samePadding = CoreML_Specification_SamePadding()
            return .same(samePadding)
        case .SizeFull:
            var validPadding = CoreML_Specification_ValidPadding()
            var borderAmounts = CoreML_Specification_BorderAmounts()
            var leftRightBorderAmounts = CoreML_Specification_BorderAmounts.EdgeSizes()
            leftRightBorderAmounts.startEdgeSize = UInt64((kernelWidth - 1) / 2)
            leftRightBorderAmounts.endEdgeSize = UInt64((kernelWidth - 1) / 2)
            var topBottomBorderAmounts = CoreML_Specification_BorderAmounts.EdgeSizes()
            topBottomBorderAmounts.startEdgeSize = UInt64((kernelHeight - 1) / 2)
            topBottomBorderAmounts.endEdgeSize = UInt64((kernelHeight - 1) / 2)
            borderAmounts.borderAmounts = [topBottomBorderAmounts, leftRightBorderAmounts]
            validPadding.paddingAmounts = borderAmounts
            return .valid(validPadding)
        case .Custom:
            var validPadding = CoreML_Specification_ValidPadding()
            var borderAmounts = CoreML_Specification_BorderAmounts()
            var leftRightBorderAmounts = CoreML_Specification_BorderAmounts.EdgeSizes()
            leftRightBorderAmounts.startEdgeSize = UInt64(XOffset)
            leftRightBorderAmounts.endEdgeSize = UInt64(clipWidth - inputSize[0])
            var topBottomBorderAmounts = CoreML_Specification_BorderAmounts.EdgeSizes()
            topBottomBorderAmounts.startEdgeSize = UInt64(YOffset)
            topBottomBorderAmounts.endEdgeSize = UInt64(clipHeight - inputSize[1])
            borderAmounts.borderAmounts = [topBottomBorderAmounts, leftRightBorderAmounts]
            validPadding.paddingAmounts = borderAmounts
            return .valid(validPadding)
        }
    }
    
    func transposedFullyConnectedWeightArray(inputSize: [Int]) -> [Float]
    {
        //  Transpose weight array for MLModel.  MPSCNN uses [Cout, H, W, Cin],  MLModel uses [Cout, Cin, H, W]
        
        //  If Cin is 1, the weight array is fine as is
        let Cin = inputSize[2] * inputSize[3]
        if (Cin == 1) { return weightArray! }
        
        //  Create a transposed matrix
        var transposedWeights = [Float](repeating: 0.0, count: weightArray!.count)
        var index = 0
        let singleChannelSize = inputSize[1] * inputSize[0]
        for outChannel in 0..<numChannels {
            let destCoutStart = outChannel * Cin * singleChannelSize
            for y in 0..<inputSize[1] {
                for x in 0..<inputSize[0] {
                    for inChannel in 0..<Cin {
                        let destIndex = destCoutStart + inChannel * singleChannelSize + y * inputSize[0] + x
                        transposedWeights[destIndex] = weightArray![index]
                        index += 1
                    }
                }
            }
        }
        
        return transposedWeights
    }

    func getActivationNonLinearity() throws -> CoreML_Specification_ActivationParams.OneOf_NonlinearityType
    {
        let activationType = NeuronSubType(rawValue: subType)!
        switch (activationType) {
        case .Absolute:
            throw MLModelExportError.unsupportedActivationType
        case .ELU:
            var activationELUParams = CoreML_Specification_ActivationELU()
            activationELUParams.alpha = additionalData[0]
            return .elu(activationELUParams)
        case .HardSigmoid:
            var activationSigmoidHardParams = CoreML_Specification_ActivationSigmoidHard()
            activationSigmoidHardParams.alpha = additionalData[0]
            activationSigmoidHardParams.beta = additionalData[1]
            return .sigmoidHard(activationSigmoidHardParams)
        case .Linear:
            var activationLinearParams = CoreML_Specification_ActivationLinear()
            activationLinearParams.alpha = additionalData[0]
            activationLinearParams.beta = additionalData[1]
            return .linear(activationLinearParams)
        case .PReLU:
            let activationPReLUParams = CoreML_Specification_ActivationPReLU()
            //!!  get parameters
            return .preLu(activationPReLUParams)
        case .ReLUN:
            throw MLModelExportError.unsupportedActivationType
//            var activationReLUNParams = CoreML_Specification_ActivationThresholdedReLU()
//            activationReLUNParams.alpha = additionalData[1]
//            return .thresholdedReLu(activationReLUNParams)
        case .ReLU:
            let activationReLUParams = CoreML_Specification_ActivationReLU()
            return .reLu(activationReLUParams)
        case .Sigmoid:
            let activationSigmoidParams = CoreML_Specification_ActivationSigmoid()
            return .sigmoid(activationSigmoidParams)
        case .SoftPlus:
            let activationSoftPlusParams = CoreML_Specification_ActivationSoftplus()
            return .softplus(activationSoftPlusParams)
        case .SoftSign:
            let activationSoftSignParams = CoreML_Specification_ActivationSoftsign()
            return .softsign(activationSoftSignParams)
        case .TanH:
            if (additionalData[0] != 1.0 || additionalData[1] != 1.0) {
                var activationTanHParams = CoreML_Specification_ActivationScaledTanh()
                activationTanHParams.alpha = additionalData[0]
                activationTanHParams.beta = additionalData[1]
                return .scaledTanh(activationTanHParams)
            }
            else {
                let activationTanHParams = CoreML_Specification_ActivationTanh()
                return .tanh(activationTanHParams)
            }
        case .Exponential:
            throw MLModelExportError.unsupportedActivationType
        case .Logarithm:
            throw MLModelExportError.unsupportedActivationType
        case .Power:
            throw MLModelExportError.unsupportedActivationType
        }
    }

    func generateLayerName(flowIndex: Int, layerIndex : Int) -> String
    {
        let string = "Flow_\(flowIndex)_" + type.typeString + "\(layerIndex)"
        return string
    }
    
    func transposeMLModelWeights(_ dimensions: [Int])
    {
        //  Transpose weight array from MLModel.  MPSCNN uses [Cout, H, W, Cin],  MLModel uses [Cout, Cin, H, W]
        
        //  Only needed for layers with weights
        switch (type) {
        case .Convolution:
            //  If Cin is 1, the weight array is fine as is
            let Cin = dimensions[2] * dimensions[3]
            if (Cin == 1) { return }
            
            //  Create a transposed matrix
            var transposedWeights = [Float](repeating: 0.0, count: weightArray!.count)
            var index = 0
            let singleKernelSize = kernelHeight * kernelWidth
            for outChannel in 0..<numChannels {
                let sourceCoutStart = outChannel * Cin * singleKernelSize
                for y in 0..<kernelHeight {
                    for x in 0..<kernelWidth {
                        for inChannel in 0..<Cin {
                            let sourceIndex = sourceCoutStart + inChannel * singleKernelSize + y * kernelWidth + x
                            transposedWeights[index] = weightArray![sourceIndex]
                            index += 1
                        }
                    }
                }
            }
            weightArray = transposedWeights
            
        case .FullyConnected:
            //  If Cin is 1, the weight array is fine as is
            let Cin = dimensions[2] * dimensions[3]
            if (Cin == 1) { return }
            
            //  Create a transposed matrix
            var transposedWeights = [Float](repeating: 0.0, count: weightArray!.count)
            var index = 0
            let singleChannelSize = dimensions[1] * dimensions[0]
            for outChannel in 0..<numChannels {
                let sourceCoutStart = outChannel * Cin * singleChannelSize
                for y in 0..<dimensions[1] {
                    for x in 0..<dimensions[0] {
                        for inChannel in 0..<Cin {
                            let sourceIndex = sourceCoutStart + inChannel * singleChannelSize + y * dimensions[0] + x
                            transposedWeights[index] = weightArray![sourceIndex]
                            index += 1
                        }
                    }
                }
            }
            weightArray = transposedWeights
            
        default:
            return
        }
    }

}
