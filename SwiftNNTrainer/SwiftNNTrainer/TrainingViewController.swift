//
//  DataViewController.swift
//  SwiftNNTrainer
//
//  Created by Kevin Coble on 2/8/19.
//  Copyright © 2019 Kevin Coble. All rights reserved.
//

import Cocoa
import MetalPerformanceShaders
import MetalKit
import SceneKit
import GameplayKit

class TrainingViewController: NSViewController
{
    @IBOutlet weak var averageError: NSTextField!
    @IBOutlet weak var classificationPercentage: NSTextField!
    @IBOutlet weak var batchSize: NSTextField!
    @IBOutlet weak var batchSizeStepper: NSStepper!
    @IBOutlet weak var batchRandomRadio: NSButton!
    @IBOutlet weak var sampleSetRadio: NSButton!
    @IBOutlet weak var sequentialRadio: NSButton!
    @IBOutlet weak var numEpochs: NSTextField!
    @IBOutlet weak var numEpochsStepper: NSStepper!
    @IBOutlet weak var learningRate: NSTextField!
    @IBOutlet weak var trainButton: NSButton!
    @IBOutlet weak var trainingProgressBar: NSProgressIndicator!
    @IBOutlet weak var testAfterEpoch: NSButton!
    @IBOutlet weak var testingEpochs: NSTextField!
    @IBOutlet weak var testingEpochsStepper: NSStepper!
    @IBOutlet weak var subsetCheckbox: NSButton!
    @IBOutlet weak var subsetField: NSTextField!
    @IBOutlet weak var subsetStepper: NSStepper!
    @IBOutlet weak var viewTestResultsButton: NSButton!
    @IBOutlet weak var testingProgressBar: NSProgressIndicator!
    @IBOutlet weak var testButton: NSButton!
    @IBOutlet weak var plotView: PlotView!
    @IBOutlet weak var totalSamples: NSTextField!
    
    var continueRunning = AtomicBool(false)
    var trainingHistory : [(epoch: Int, averageError: Float)]?
    var continueTesting = AtomicBool(false)
    var testingResults : [(output:[Float], outputClass: Int)?] = []
    var testingStartTime : CFTimeInterval = 0.0
    var testingStatistics : (averageError : Float, classificationPercentage : Float)?
    var updateTestingProgress = false
    
    var document : Document? //  Local pointer
    
    override func viewDidLoad() {
        super.viewDidLoad()
        plotView.calculateLabelInformation()
        
        //  Set the learning rate to use significant digits
        let formatter = learningRate.formatter! as! NumberFormatter
        formatter.usesSignificantDigits = true
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    @IBAction func onBatchSizeChanged(_ sender: NSTextField) {
        //  Set the stepper from the text field
        if (batchSizeStepper.integerValue == sender.integerValue) {return}       //  Stop loops
        batchSizeStepper.integerValue = Int(sender.integerValue)
        //  Set the value in the document
        guard let doc = document else { return }
        doc.docData.batchSize = sender.integerValue
    }
    @IBAction func onBatchSizeStepperChanged(_ sender: NSStepper) {
        //  Set the text field from the stepper
        if (batchSize.integerValue == sender.integerValue) {return}       //  Stop loops
        batchSize.integerValue = Int(sender.integerValue)
        //  Set the value in the document
        guard let doc = document else { return }
        doc.docData.batchSize = sender.integerValue
   }
    @IBAction func onSetBatchSizeFromTrainingData(_ sender: NSButton) {
        //  Get the document
        guard let doc = document else { return }
        
        //  Set the batch size to the sample size
        var setValue = doc.numTrainingSamples
        if (setValue == 0) { setValue = 1 }
        batchSize.integerValue = setValue
        batchSizeStepper.integerValue = setValue
        doc.docData.batchSize = sender.integerValue
    }
    
    @IBAction func onBatchIndicesMethodChanged(_ sender: NSButton) {
        //  Get the document
        guard let doc = document else { return }
        
        if let newMethod = BatchIndicesSource(rawValue: sender.tag) {
            doc.docData.batchIndicesSource = newMethod
        }
    }
    
    @IBAction func onNumEpochsChanged(_ sender: NSTextField) {
        //  Set the stepper from the text field
        if (numEpochsStepper.integerValue == sender.integerValue) {return}       //  Stop loops
        numEpochsStepper.integerValue = Int(sender.integerValue)
        //  Set the value in the document
        guard let doc = document else { return }
        doc.docData.numEpochs = sender.integerValue
    }
    
    @IBAction func onNumEpochsStepperChanged(_ sender: NSStepper) {
        //  Set the text field from the stepper
        if (numEpochs.integerValue == sender.integerValue) {return}       //  Stop loops
        numEpochs.integerValue = Int(sender.integerValue)
        //  Set the value in the document
        guard let doc = document else { return }
        doc.docData.numEpochs = sender.integerValue
    }
    
    @IBAction func onTestAfterEpochChanged(_ sender: NSButton) {
        //  Set the value in the document
        guard let doc = document else { return }
        doc.docData.testAfterEpoch = (sender.state == .on)
    }
    
    @IBAction func onTestingEpochsChanged(_ sender: NSTextField) {
        //  Set the stepper from the text field
        if (testingEpochsStepper.integerValue == sender.integerValue) {return}       //  Stop loops
        testingEpochsStepper.integerValue = sender.integerValue
        //  Set the value in the document
        guard let doc = document else { return }
        doc.docData.epochsBetweenTests = sender.integerValue
    }
    
    @IBAction func onTestingEpochsStepperChanged(_ sender: NSStepper) {
        //  Set the text field from the stepper
        if (testingEpochs.integerValue == sender.integerValue) {return}       //  Stop loops
        testingEpochs.integerValue = sender.integerValue
        //  Set the value in the document
        guard let doc = document else { return }
        doc.docData.epochsBetweenTests = sender.integerValue
    }
    
    @IBAction func onLearningRateChanged(_ sender: NSTextField) {
        //  Set the value in the document
        guard let doc = document else { return }
        doc.docData.learningRate = sender.floatValue
    }
    
    @IBAction func onUseSubsetChanged(_ sender: NSButton) {
        //  Set the value in the document
        guard let doc = document else { return }
        doc.docData.useSubsetForTest = (sender.state == .on)
        
        //  Set the rest of the controls based on the change
        configureTestSubset()
    }
    
    @IBAction func onSubsetSizeChanged(_ sender: NSTextField) {
        //  Validate the value against the number of training samples
        guard let doc = document else { return }
        var value = sender.integerValue
        //  Validate the subset size if we have loaded data
        let trainingDataSize = doc.numTrainingSamples
        if (trainingDataSize > 0 && value > trainingDataSize) {
            value = trainingDataSize
        }

        //  Set the stepper from the text field
        if (subsetStepper.integerValue == value) {return}       //  Stop loops
        subsetStepper.integerValue = value
        //  Set the value in the document
        doc.docData.testSubsetSize = sender.integerValue
    }
    
    @IBAction func onSubsetSizeStepperChanged(_ sender: NSStepper) {
        //  Set the text field from the stepper
        if (subsetField.integerValue == sender.integerValue) {return}       //  Stop loops
        subsetField.integerValue = Int(sender.integerValue)
        //  Set the value in the document
        guard let doc = document else { return }
        doc.docData.testSubsetSize = sender.integerValue
    }
    
    @IBAction func onInitializeWeights(_ sender: Any) {
        //  Get the document
        document = view.window?.windowController?.document as? Document
        guard let doc = document else { return }
        
        //  If the weights are already initialize, ask the user
        if (!doc.docData.needsWeightInitialization) {
            let alert = NSAlert()
            alert.addButton(withTitle: "Continue")
            alert.addButton(withTitle: "Cancel")
            alert.messageText = "Weights Previously Initialized"
            alert.informativeText = "Re-initializing will lose any training performed"
            alert.alertStyle = .warning
            alert.beginSheetModal(for: self.view.window!) { returnCode in
                if (returnCode == .alertFirstButtonReturn) {
                    doc.initializeWeights()
                    self.totalSamples.integerValue = doc.docData.totalTrainingSamples
                    self.trainingHistory = nil
                    self.plotView.plotData = []
                    self.plotView.setNeedsDisplay(self.plotView.bounds)
                }
            }
        }
        
        else {
            doc.initializeWeights()
            totalSamples.integerValue = doc.docData.totalTrainingSamples
            trainingHistory = nil
        }
    }
    
    @IBAction func onViewResults(_ sender: Any) {
        //  Ignore if no results
        if (testingResults.count <= 0) { return }
        
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        
        let storyboard = NSStoryboard(name: "DataAsImage", bundle: nil)
        let controller = storyboard.instantiateController(withIdentifier: "Data As Image") as! NSWindowController
        let dataAsImageViewController = controller.contentViewController as! DataAsImageViewController
        dataAsImageViewController.data = doc.trainingData?.testingData
        dataAsImageViewController.results = testingResults
        dataAsImageViewController.dataInputDimensions = doc.trainingData?.inputDimensions
        dataAsImageViewController.dataOutputDimensions = doc.trainingData?.outputDimensions
        dataAsImageViewController.regression = (doc.outputType == .Regression)
        
        //  Activate the sheet to load the data
        NSApplication.shared.mainWindow!.beginSheet(controller.window!, completionHandler:{(returnCode:NSApplication.ModalResponse) -> Void in
            //  Remove the sheet
            controller.window!.orderOut(self)
        })
    }
    
    func configureTestSubset()
    {
        //  Get the document
        guard let doc = document else { return }
        
        //  Set the controls based on the settings
        if (doc.docData.useSubsetForTest) {
            //  Validate the subset size if we have loaded data
            let testingDataSize = doc.numTestingSamples
            if (testingDataSize > 0) {
                if (testingDataSize < doc.docData.testSubsetSize) {
                    doc.docData.testSubsetSize = testingDataSize
                }
                subsetStepper.maxValue = Double(testingDataSize)
            }
            
            subsetField.integerValue = doc.docData.testSubsetSize
            subsetStepper.integerValue = doc.docData.testSubsetSize
            subsetField.isEnabled = true
            subsetStepper.isEnabled = true
        }
        else {
            subsetField.stringValue = ""
            subsetField.isEnabled = false
            subsetStepper.isEnabled = false
        }
    }
    
    override func viewDidAppear()
    {
        //  Get the document
        document = view.window?.windowController?.document as? Document
        guard let doc = document else { return }
        viewTestResultsButton.isEnabled = false

        //  Set the controls from the data
        batchSize.integerValue = doc.docData.batchSize
        batchSizeStepper.integerValue = doc.docData.batchSize
        numEpochs.integerValue = doc.docData.numEpochs
        numEpochsStepper.integerValue = doc.docData.numEpochs
        testAfterEpoch.state = doc.docData.testAfterEpoch ? .on : .off
        testingEpochs.integerValue = doc.docData.epochsBetweenTests
        testingEpochsStepper.integerValue = doc.docData.epochsBetweenTests
        learningRate.floatValue = doc.docData.learningRate
        subsetCheckbox.state = doc.docData.useSubsetForTest ? .on : .off
        configureTestSubset()
        viewTestResultsButton.isEnabled = false
        totalSamples.integerValue = doc.docData.totalTrainingSamples
        switch (doc.docData.batchIndicesSource) {
        case .sequential:
            sequentialRadio.state = .on
        case .batchRandom:
            batchRandomRadio.state = .on
        case .testSetRandom:
            sampleSetRadio.state = .on
        }

        //  Update the plot view
        plotView.calculateLabelInformation()
        plotView.setNeedsDisplay(plotView.bounds)
    }

    @IBAction func onDebug(_ sender: NSButton) {

        //  Get the metal device
        guard let metalDevice = MTLCreateSystemDefaultDevice() else { return }
        
        let commandQueue = metalDevice.makeCommandQueue()!

        guard let doc = document else { return }
        doc.initializeWeights()
        let _ = doc.getForwardGraph(commandQueue: commandQueue)!
        guard let testingData = doc.getTestingSample(sampleNumber: 0) else {
            return
        }
        //  Convert the training sample to an input set
        let testImage2 = convertInputToImage(metalDevice: metalDevice, dimensions: doc.docData.inputDimensions, inputData: testingData.input)
        print("input size = \(testImage2.width)x\(testImage2.height)x\(testImage2.featureChannels)" )
        
        for i in 0..<doc.docData.flows[0].layers.count {
            let graph3 = MPSNNGraph(device: commandQueue.device, resultImage: doc.docData.flows[0].layers[i].lastNode!.resultImage, resultImageIsNeeded: true)!
            
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
                if (doc.docData.flows[0].layers[i].type == .Convolution) {
                    if let weights = doc.docData.flows[0].layers[i].weightArray {
                        print("  Convolutional layer weight size = \(weights.count)")
                    }
                }
                if (i < 6) {
                    let features = image.getResultArray()
                    print(features)
                    var numValid = 0
                    var numNan = 0
                    for feature in features {
                        if (feature.isNaN) {
                            numNan += 1
                        }
                        else {
                            numValid += 1
                        }
                    }
                    print("Num valid = \(numValid)")
                    print("Num NaN = \(numNan)")
                }
            }
        }

    }
    
    @IBAction func OnTest(_ sender: Any)
    {
        //  If already testing, stop when we can
        if (continueTesting.state) {
            continueTesting.state = false
            return
        }
        
        //  Get the document
        guard let doc = document else { return }
        
        //  Get the metal device
        guard let metalDevice = MTLCreateSystemDefaultDevice() else { return }
        
        let commandQueue = metalDevice.makeCommandQueue()!
        
        //  Make sure we have a valid network
        if (!doc.validNetwork) {
            let alert = NSAlert()
            alert.addButton(withTitle: "OK")
            alert.messageText = "Invalid Network"
            alert.informativeText = "The current network configuration cannot be validated"
            alert.alertStyle = .warning
            alert.beginSheetModal(for: self.view.window!) { returnCode in
            }
            return
        }

        //  Make sure there is testing data
        if (doc.trainingData == nil || doc.trainingData!.testingData.count <= 0) {
            let alert = NSAlert()
            alert.addButton(withTitle: "OK")
            alert.messageText = "Testing data not loaded"
            alert.informativeText = "Return to the Data Tab and load data for testing"
            alert.alertStyle = .warning
            alert.beginSheetModal(for: self.view.window!) { returnCode in
            }
            return
        }

        //  If this is our first run since the model changed, initialize the weights
        if (doc.docData.needsWeightInitialization) {
            doc.initializeWeights()
        }

        //  Get the forward graph
        let graph = doc.getForwardGraph(commandQueue: commandQueue)
        if (graph == nil) {
            let alert = NSAlert()
            alert.addButton(withTitle: "OK")
            alert.messageText = "Error creating the forward-only MPSNNGraph object"
            alert.informativeText = "Error creating Neural Network"
            alert.alertStyle = .warning
            alert.beginSheetModal(for: view.window!) { returnCode in
            }
            return
        }
        
//        print(graph.debugDescription)
        
        //  Make sure the training data is loaded
        if (doc.trainingData == nil) {
            let alert = NSAlert()
            alert.addButton(withTitle: "OK")
            alert.messageText = "Training data not loaded"
            alert.informativeText = "Return to the Data Tab and load data"
            alert.alertStyle = .warning
            alert.beginSheetModal(for: self.view.window!) { returnCode in
            }
            return
        }
        
        //  Get a dispatch queue to do this in
        let queue = DispatchQueue(label: "training")

        //  Change the button to 'Stop'
        continueTesting.state = true
        testButton.title = "Stop"
        
        //  Set up the progress bar
        testingProgressBar.maxValue = Double(doc.numTestingSamples)
        testingProgressBar.doubleValue = 0.0
        updateTestingProgress = true

        //  Initialize the results array
        testingResults = [(output:[Float], outputClass: Int)?](repeating: nil, count: doc.numTestingSamples)

        //  Perform the test
        testingStartTime = CACurrentMediaTime()
        testingStatistics = nil
        queue.async {
            self.testingStatistics = self.doTest(graph : graph!, document : doc, numSamples : doc.numTestingSamples)
        }
        
        //  Add the completion handler to the queue
        queue.async {
            self.doneTesting()
        }
    }
    
    func doTest(graph : MPSNNGraph, document : Document, numSamples : Int) -> (averageError : Float, classificationPercentage : Float)?
    {
        //  Initialize the error counts
        var numError = 0
        var sumError : Float = 0.0
        var classificationPercentage : Float = 0.0
        
        //  Get the metal platform to perform on
        let commandQueue = graph.device.makeCommandQueue()!
        
        //  Get a serial queue for thread-safe data updates
        let queue = DispatchQueue(label: "updates")

        //  Do for each testing data item
        var sample = 0
        let numSamplesCompleted = AtomicInteger(0)
        var testIndex = [Int](repeating: 0, count: document.docData.batchSize)
        while (sample < numSamples && continueTesting.state) {
            //  Get a training sample batch
            var tempImages = [MPSImage?](repeating: nil, count: document.docData.batchSize)  //  Temp arrays to hold concurrent results
            DispatchQueue.concurrentPerform(iterations: document.docData.batchSize) { (batchIndex) in
                if ((sample + batchIndex) >= numSamples) { return }
                guard let testingData = document.getTestingSample(sampleNumber: sample + batchIndex) else { return }
                
                //  Convert the testing sample to an input set
                let testImage = convertInputToImage(metalDevice: graph.device, dimensions: document.docData.inputDimensions, inputData: testingData.input)
                
                
                //  Update the variables that leave the concurrent closure
                queue.sync {
                    testIndex[batchIndex] = sample + batchIndex
                    tempImages[batchIndex] = testImage
                }
            }
            sample += document.docData.batchSize
            
            //  Check the results and transfer the inputs into a standard array
            var testingImages : [MPSImage] = []
            var batchIndex : [Int] = []
            for index in 0..<document.docData.batchSize {
                if (tempImages[index] == nil) {continue}
                testingImages.append(tempImages[index]!)
                batchIndex.append(testIndex[index])
            }
            if (testingImages.count <= 0) { break }

            //  Run the batch
            let commandBuffer = commandQueue.makeCommandBuffer()!
            if let results = graph.encodeBatch(to: commandBuffer, sourceImages: [testingImages], sourceStates: nil) {
                //  Extract the result images
                for outputImage in results {
                    outputImage.synchronize(on: commandBuffer)
                }
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
                
                //  Check the results
                for index in 0..<testingImages.count {
                    if let testingData = document.getTestingSample(sampleNumber: batchIndex[index]) {
                        let features = results[index].getResultArray()
                        for i in 0..<features.count {
                            sumError += abs(features[i] - testingData.output[i])
                        }
                        
                        var outputClass = 0
                        if (document.outputType == .Classification) {
                            outputClass = self.getClass(features: features)
                            if (outputClass != testingData.outputClass) { numError += 1 }
                        }
                        
                        //  Store the results for viewing
                        if (testingResults.count > 0) {
                            testingResults[batchIndex[index]] = (output: features, outputClass: outputClass)
                        }
                    }
                }
                numSamplesCompleted.addValue(testingImages.count)
                if (updateTestingProgress) {
                    DispatchQueue.main.async {
                        self.testingProgressBar.doubleValue = Double(numSamplesCompleted.value)
                    }
                }
            }
        }
        
        let completed = numSamplesCompleted.value
        classificationPercentage = Float(completed - numError) / Float(completed)
        var averageError : Float
        if (completed > 0) {
            averageError = sumError / Float(completed)
        }
        else {
            averageError = -999.0
        }
        return (averageError : averageError, classificationPercentage : classificationPercentage)
    }
    
    func doneTesting()
    {
        //  Change the button back to 'Train' (on main thread)
        DispatchQueue.main.async {
            self.testButton.title = "Test"
            self.continueTesting.state = false
            
            if let results = self.testingStatistics {
                self.averageError.floatValue = results.averageError
                guard let doc = self.document else { return }
                if (doc.outputType == .Classification) {
                    self.classificationPercentage.floatValue = results.classificationPercentage * 100.0
                }
                else {
                    self.classificationPercentage.stringValue = " "
                }
                self.viewTestResultsButton.isEnabled = true
            }
            else {
                self.testingResults = []
                self.viewTestResultsButton.isEnabled = false
            }
        }

        let elapsed = CACurrentMediaTime() - testingStartTime
        print("elapsed testing time = \(elapsed)")
    }

    @IBAction func onTrain(_ sender: Any)
    {
        //  If already running something, stop when we can
        if (continueRunning.state) {
            continueRunning.state = false
            return
        }
        
        //  Get the document
        guard let doc = document else { return }

        //  Set up the progress bar
        trainingProgressBar.maxValue = Double(doc.docData.numEpochs)
        trainingProgressBar.doubleValue = 0.0
        
        //  Make sure we have a valid network
        if (!doc.validNetwork) {
            let alert = NSAlert()
            alert.addButton(withTitle: "OK")
            alert.messageText = "Invalid Network"
            alert.informativeText = "The current network configuration cannot be validated"
            alert.alertStyle = .warning
            alert.beginSheetModal(for: self.view.window!) { returnCode in
            }
            return
        }
        
        //  Make sure the training data is loaded
        if (doc.trainingData == nil) {
            let alert = NSAlert()
            alert.addButton(withTitle: "OK")
            alert.messageText = "Training data not loaded"
            alert.informativeText = "Return to the Data Tab and load data"
            alert.alertStyle = .warning
            alert.beginSheetModal(for: self.view.window!) { returnCode in
            }
            return
        }
        
        //  If testing during training, make sure there is testing data
        if (doc.docData.testAfterEpoch && doc.trainingData!.testingData.count <= 0) {
            let alert = NSAlert()
            alert.addButton(withTitle: "OK")
            alert.messageText = "Testing data not loaded"
            alert.informativeText = "Return to the Data Tab and load data for testing after epochs"
            alert.alertStyle = .warning
            alert.beginSheetModal(for: self.view.window!) { returnCode in
            }
            return
        }
 
        //  Make sure the batch size doesn't exceed the training data set
        let numSamples = doc.numTrainingSamples
        if (doc.docData.batchSize > numSamples) {
            let alert = NSAlert()
            alert.addButton(withTitle: "OK")
            alert.messageText = "The size of the batch exceeds the size of the training sample set"
            alert.informativeText = "Batch size greater than samples"
            alert.alertStyle = .warning
            alert.beginSheetModal(for: view.window!) { returnCode in
            }
            return
        }

        //  Get the metal device
        guard let metalDevice = MTLCreateSystemDefaultDevice() else { return }
        let commandQueue = metalDevice.makeCommandQueue()!
        
        //  Get a dispatch queue to do this in, and to update the concurrent thread results
        let queue = DispatchQueue(label: "epochs")
        let updateQueue = DispatchQueue(label: "updateQueue")

        //  Change the button to 'Stop'
        continueRunning.state = true
        trainButton.title = "Stop"
        
        //  If this is our first run since the model changed, initialize the weights
        if (doc.docData.needsWeightInitialization) {
            doc.initializeWeights()
        }
        
        //  Get the forward/loss/backward graph
        doc.setMainLearningRate()
        let graph = doc.getFullForwardBackwardGraph(commandQueue: commandQueue)
        if (graph == nil) {
            let alert = NSAlert()
            alert.addButton(withTitle: "OK")
            alert.messageText = "Error creating the forward-backward MPSNNGraph object"
            alert.informativeText = "Error creating Neural Network"
            alert.alertStyle = .warning
            alert.beginSheetModal(for: view.window!) { returnCode in
            }
            return
        }
        
        //  Clear the epoch statistics
        var historicalEpochs = 0
        if (trainingHistory == nil) {
            trainingHistory = []
        }
        else {
            if (trainingHistory!.count > 0) {
                let lastHistory = trainingHistory!.last!
                historicalEpochs = lastHistory.epoch
            }
        }
        
        //  Do initial testing (if indicated)
        var forwardGraph : MPSNNGraph?
        var testingSize = 0
        updateTestingProgress = false
        if (doc.docData.testAfterEpoch) {
            testingResults = []
            viewTestResultsButton.isEnabled = false
            forwardGraph = doc.getForwardHalfOfFullGraph(commandQueue: commandQueue)
            if let forwardGraph = forwardGraph {
                testingSize = doc.numTestingSamples
                if (doc.docData.useSubsetForTest) {
                    if (doc.docData.testSubsetSize <= testingSize) { testingSize = doc.docData.testSubsetSize }
                }
                continueTesting.state = true
                if let result = doTest(graph: forwardGraph, document: doc, numSamples: testingSize) {
                    trainingHistory?.append((epoch: historicalEpochs, averageError: result.averageError))
                }
                continueTesting.state = false
            }
        }
        var epochsSinceTest = 0
        var lastPlotUpdateTime = CACurrentMediaTime()
        var sourceIndices : [Int] = []
        var sourceIndexStart = 0
        if (doc.docData.batchIndicesSource == .testSetRandom) {
            let sequence = 0 ..< numSamples
            sourceIndices = sequence.shuffled()
        }

        //  Do for each of the epochs
        let numOutputs = doc.docData.outputDimensions.reduce(1, *)
        for epoch in 0..<doc.docData.numEpochs {
            queue.async {
                autoreleasepool {
                    if (self.continueRunning.state) {       //  Early exit requested
                    
                        //  Get the sample indices for this batch
                        var indices : [Int] = []
                        switch (doc.docData.batchIndicesSource) {
                            case .sequential:
                                for _ in 0..<doc.docData.batchSize {
                                    indices.append(sourceIndexStart)
                                    sourceIndexStart += 1
                                    if (sourceIndexStart >= numSamples) { sourceIndexStart = 0 }
                                }
                            case .batchRandom:
                                if (doc.docData.batchSize > numSamples / 4) {
                                    let sequence = 0 ..< numSamples
                                    indices = sequence.shuffled()
                                }
                                else {
                                    indices = []
                                    while (indices.count < doc.docData.batchSize) {
                                        let newEntry = Int.random(in: 0..<numSamples)
                                        if (!indices.contains(newEntry)) { indices.append(newEntry) }
                                    }
                                }
                            case .testSetRandom:
                                if (sourceIndexStart + doc.docData.batchSize > numSamples) {
                                    let sequence = 0 ..< numSamples
                                    sourceIndices = sequence.shuffled()
                                    sourceIndexStart = 0
                                }
                                for _ in 0..<doc.docData.batchSize {
                                    indices.append(sourceIndices[sourceIndexStart])
                                    sourceIndexStart += 1
                                }
                       }
                        
                        //  Create the batch set
                        var trainingImages : [MPSImage] = []
                        var lossLabels : [MPSCNNLossLabels] = []
                        var tempImages = [MPSImage?](repeating: nil, count: doc.docData.batchSize)  //  Temp arrays to hold concurrent results
                        var tempLabels = [MPSCNNLossLabels?](repeating: nil, count: doc.docData.batchSize)

                        let _ = DispatchQueue.global(qos: .userInitiated)
                        DispatchQueue.concurrentPerform(iterations: doc.docData.batchSize) { (batchIndex) in
                            guard let trainingData = doc.getTrainingSample(sampleNumber: indices[batchIndex]) else { return }

                            //  Convert the training sample to an input set
                            let trainingImage = self.convertInputToImage(metalDevice: metalDevice, dimensions: doc.docData.inputDimensions, inputData: trainingData.input)
                            
                            //  Convert the training sample to a result state
                            let labelData = Data(bytes: UnsafeRawPointer(trainingData.output), count: numOutputs * MemoryLayout<Float>.size)
                            let labelDesc = MPSCNNLossDataDescriptor(data: labelData,
                                                                     layout: .featureChannelsxHeightxWidth,
                                                                     size: MTLSize(width: doc.docData.outputDimensions[0], height: doc.docData.outputDimensions[1], depth: doc.docData.outputDimensions[2] * doc.docData.outputDimensions[3]))!
                            let lossLabel = MPSCNNLossLabels(device: metalDevice, labelsDescriptor: labelDesc)
                            
                            //  Update the variables that leave the concurrent closure
                            updateQueue.sync {
                                tempImages[batchIndex] = trainingImage
                                tempLabels[batchIndex] = lossLabel
                            }
                        }
                        
                        //  Check the results and transfer the inputs into a standard array
                        for index in 0..<doc.docData.batchSize {
                            if (tempImages[index] == nil || tempLabels[index] == nil) {return}
                            trainingImages.append(tempImages[index]!)
                            lossLabels.append(tempLabels[index]!)
                        }
                        
                        //  Run the batch
                        let commandBuffer = commandQueue.makeCommandBuffer()!
                        let _ = graph!.encodeBatch(to: commandBuffer, sourceImages: [trainingImages], sourceStates: [lossLabels])

                        //  Get the weights out
                        for flow in doc.docData.flows {
                            for layer in flow.layers {
                                if (layer.type == .Convolution || layer.type == .FullyConnected) {
                                    layer.synchronizeWeightsAndBias(buffer: commandBuffer)
                                }
                            }
                        }
                        
                        //  Commit the commands to the GPU
                        commandBuffer.commit()
                        commandBuffer.waitUntilCompleted()
                        
                        //  Extract the weights and biases
                        for flow in doc.docData.flows {
                            for layer in flow.layers {
                                if (layer.type == .Convolution || layer.type == .FullyConnected) {
                                    layer.extractWeightsAndBias()
                                }
                            }
                        }
                        
                        //  Update the training samples
                        doc.docData.totalTrainingSamples += doc.docData.batchSize
                        
                        //  If testing after the epoch, do so now
                        if (doc.docData.testAfterEpoch) {
                            epochsSinceTest += 1
                            if (epochsSinceTest == doc.docData.epochsBetweenTests || epoch >= doc.docData.numEpochs-1) {
                                forwardGraph = doc.getForwardHalfOfFullGraph(commandQueue: commandQueue)
                                if let forwardGraph = forwardGraph {
                                    self.continueTesting.state = true
                                    if let result = self.doTest(graph: forwardGraph, document: doc, numSamples: testingSize) {
                                        self.trainingHistory?.append((epoch: historicalEpochs + epoch, averageError: result.averageError))
                                        
                                        //  Periodically update the plot
                                        let currentTime = CACurrentMediaTime()
                                        if ((currentTime - lastPlotUpdateTime) > 1.0) {
                                            DispatchQueue.main.async {
                                                self.updatePlot()
                                            }
                                            lastPlotUpdateTime = currentTime
                                        }
                                    }
                                    self.continueTesting.state = false
                                }
                                epochsSinceTest = 0
                            }
                        }
                        
                        //  Update the progress bar
                        DispatchQueue.main.async {
                            self.trainingProgressBar.doubleValue = Double(epoch)
                            self.totalSamples.integerValue = doc.docData.totalTrainingSamples
                        }

                    }
                }
            }
        }
        
        queue.async {
            self.doneTraining()
        }
    }
    
    func updatePlot() {
        if let history = self.trainingHistory {
            if (history.count > 0) {
                var points : [(x : CGFloat, y : CGFloat)] = []
                for pt in history {
                    points.append((x : CGFloat(pt.epoch) , y : CGFloat(pt.averageError)))
                }
                let pd = PlotData(points : points, connected : true, color : NSColor.red)
                self.plotView.plotData = [pd]
                self.plotView.scaleToData()
                self.plotView.calculateLabelInformation()
                self.plotView.setNeedsDisplay(self.plotView.bounds)
            }
        }
    }
    
    func doneTraining()
    {
        //  Change the button back to 'Train' (on main thread)
        DispatchQueue.main.async {
            self.trainButton.title = "Train"
            self.continueRunning.state = false
            
            self.updatePlot()
        }
    }
    
    func convertInputToImage(metalDevice: MTLDevice, dimensions: [Int], inputData: [Float]) -> MPSImage
    {
        let actualChannels = dimensions[2] * dimensions[3]      //  Number of image channels being sent
        let numSlices = (actualChannels + 3) / 4                //  Number of slices to send all the image channels
        var sliceChannels = actualChannels                      //  Number of image channels in each slice
        if (sliceChannels > 2) {sliceChannels = 4}
        
        let inputDesc = MPSImageDescriptor(channelFormat: .float32, width: dimensions[0], height: dimensions[1], featureChannels: dimensions[2] * dimensions[3])
        inputDesc.storageMode = .managed
        let image = MPSImage(device: metalDevice, imageDescriptor: inputDesc)
        
        let channelSize = dimensions[0] * dimensions[1]     //  Input data offset between each data channel (dimension 2)
        let timeSize = channelSize * dimensions[2]          //  Input data offset between each data time (dimension 3)

        for slice in 0..<numSlices {
            var sliceData = [Float](repeating: 0, count: sliceChannels * dimensions[0] * dimensions[1])
            var sliceIndex = 0
            for row in 0..<dimensions[1] {
                for column in 0..<dimensions[0] {
                    for sliceChannel in 0..<sliceChannels {
                        let imageChannel = 4 * slice + sliceChannel
                        if imageChannel < actualChannels {
                            let channel = imageChannel % dimensions[2]      //  Which data channel is being put in this slice channel
                            let time = imageChannel / dimensions[2]         //  Which 'time' is being put in this slice channel
                            sliceData[sliceIndex] = inputData[time * timeSize + channel * channelSize + row * dimensions[0] + column]
                        }
                        sliceIndex += 1
                    }
                }
            }

            image.texture.replace(
                region: MTLRegionMake2D(0, 0, dimensions[0], dimensions[1]),
                mipmapLevel: 0,
                slice: slice,
                withBytes: UnsafeRawPointer(sliceData),
                bytesPerRow: sliceChannels * dimensions[0] * MemoryLayout<Float>.size,
                bytesPerImage: sliceChannels * dimensions[0] * dimensions[1] * MemoryLayout<Float>.size
            )
        }
        
        return image
    }
    
    func getClass(features : [Float]) -> Int
    {
        if (features.count > 1) {
            var best = 0;
            var bestOutput = -Float.infinity
            for i in 0..<features.count {
                if (features[i] > bestOutput) {
                    bestOutput = features[i]
                    best = i
                }
            }
            return best
        }
        else {
            return features[0] > 0.5 ? 1 : 0
        }
    }
    
    func getExpectedOutputFromClass(outputClass : Int, dimensions : [Int]) -> [Float]
    {
        let numOutputs = dimensions.reduce(1, *)
        var output = [Float](repeating: 0.0, count: numOutputs)
        
        if (numOutputs < outputClass || outputClass == 0) {
            return output
        }
        
        output[outputClass] = 1.0
        return output
    }
}

