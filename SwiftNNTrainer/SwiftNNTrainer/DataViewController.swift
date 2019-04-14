//
//  DataViewController.swift
//  SwiftNNTrainer
//
//  Created by Kevin Coble on 2/8/19.
//  Copyright © 2019 Kevin Coble. All rights reserved.
//

import Cocoa

class DataViewController: NSViewController
{
    @IBOutlet weak var inputDimension1: NSTextField!
    @IBOutlet weak var inputDimension2: NSTextField!
    @IBOutlet weak var inputDimension3: NSTextField!
    @IBOutlet weak var inputDimension4: NSTextField!
    @IBOutlet weak var splitChannelsButton: NSButton!
    @IBOutlet weak var outputDimension1: NSTextField!
    @IBOutlet weak var outputDimension2: NSTextField!
    @IBOutlet weak var outputDimension3: NSTextField!
    @IBOutlet weak var outputDimension4: NSTextField!
    @IBOutlet weak var generatedInput: NSButton!
    @IBOutlet weak var folderInput: NSButton!
    @IBOutlet weak var fileInput: NSButton!
    @IBOutlet weak var trainingInputSourceBrowseButton: NSButton!
    @IBOutlet weak var trainingInputDataPath: NSPathControl!
    @IBOutlet weak var outputClassification: NSButton!
    @IBOutlet weak var outputRegression: NSButton!
    @IBOutlet weak var fixedColumn: NSButton!
    @IBOutlet weak var commaSeparated: NSButton!
    @IBOutlet weak var spaceDelimited: NSButton!
    @IBOutlet weak var imageInFolders: NSButton!
    @IBOutlet weak var binaryStyle: NSButton!
    @IBOutlet weak var setInputFormatButton: NSButton!
    @IBOutlet weak var seperateOutputSource: NSButton!
    @IBOutlet weak var folderOutput: NSButton!
    @IBOutlet weak var fileOutput: NSButton!
    @IBOutlet weak var outputSourceBrowseButton: NSButton!
    @IBOutlet weak var trainingOutputDataPath: NSPathControl!
    @IBOutlet weak var fixedColumnOutput: NSButton!
    @IBOutlet weak var commaSeparatedOutput: NSButton!
    @IBOutlet weak var spaceDelimitedOutput: NSButton!
    @IBOutlet weak var binaryStyleOutput: NSButton!
    @IBOutlet weak var setOutputFormatButton: NSButton!
    @IBOutlet weak var labelFile: NSButton!
    @IBOutlet weak var labelBrowseButton: NSButton!
    @IBOutlet weak var labelFilePath: NSPathControl!
    @IBOutlet weak var separateTestingSource: NSButton!
    @IBOutlet weak var testingInputSourceBrowseButton: NSButton!
    @IBOutlet weak var testingInputDataPath: NSPathControl!
    @IBOutlet weak var testingOutputSourceBrowseButton: NSButton!
    @IBOutlet weak var testingOutputDataPath: NSPathControl!
    @IBOutlet weak var createTestDataButton: NSButton!
    @IBOutlet weak var fromBeginning: NSButton!
    @IBOutlet weak var randomSamples: NSButton!
    @IBOutlet weak var fromEnd: NSButton!
    @IBOutlet weak var testDataPercentage: NSTextField!
    @IBOutlet weak var loadButton: NSButton!
    @IBOutlet weak var numSamples: NSTextField!
    @IBOutlet weak var numTestingSamples: NSTextField!
    @IBOutlet weak var viewTrainingDataButton: NSButton!
    @IBOutlet weak var viewTestingDataButton: NSButton!
    @IBOutlet weak var loadStatusField: NSTextField!
    
    var continueLoading = false
    var updateTimer : DispatchSourceTimer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
            viewDidAppear()
        }
    }
    
    func setControlState(allOff : Bool = false)
    {
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        let docData = doc.docData
        
        //  Input dimensions
        inputDimension1.isEnabled = !allOff
        inputDimension2.isEnabled = !allOff
        inputDimension3.isEnabled = !allOff
        inputDimension4.isEnabled = !allOff
        
        //  Split channels
        var enable = (!allOff && (docData.inputDimensions[2] > 1 || docData.inputDimensions[3] > 1))
        splitChannelsButton.isEnabled = enable

        //  Output dimensions
        outputDimension1.isEnabled = !allOff
        outputDimension2.isEnabled = !allOff
        outputDimension3.isEnabled = !allOff
        outputDimension4.isEnabled = !allOff
        
        //  Data source type
        generatedInput.isEnabled = !allOff
        folderInput.isEnabled = !allOff
        fileInput.isEnabled = !allOff
        
        //  Model type
        outputClassification.isEnabled = !allOff
        outputRegression.isEnabled = !allOff
        
        //  Input source controls
        enable = (!allOff && docData.trainingDataInputSource != .Generated)
        trainingInputDataPath.isEnabled = enable
        trainingInputSourceBrowseButton.isEnabled = enable
        
        //  Input data format controls
        enable = (!allOff && docData.trainingDataInputSource != .Generated)
        fixedColumn.isEnabled = enable
        commaSeparated.isEnabled = enable
        spaceDelimited.isEnabled = enable
        imageInFolders.isEnabled = (enable && docData.outputType == .Classification && docData.trainingDataInputSource == .EnclosingFolder)
        binaryStyle.isEnabled = enable
        setInputFormatButton.isEnabled = (enable && docData.inputFormat != .ImagesInFolders)
        
        //  Output source controls
        enable = (!allOff && docData.trainingDataInputSource != .Generated && docData.inputFormat != .ImagesInFolders)
        seperateOutputSource.isEnabled = enable
        enable = (enable && docData.separateOutputSource)
        folderOutput.isEnabled = enable
        fileOutput.isEnabled = enable
        outputSourceBrowseButton.isEnabled = enable
        trainingOutputDataPath.isEnabled = enable
        
        //  Output data format controls
        enable = (!allOff && docData.trainingDataInputSource != .Generated && docData.inputFormat != .ImagesInFolders && docData.separateOutputSource)
        fixedColumnOutput.isEnabled = enable
        commaSeparatedOutput.isEnabled = enable
        spaceDelimitedOutput.isEnabled = enable
        binaryStyleOutput.isEnabled = enable
        setOutputFormatButton.isEnabled = enable
        
        //  Label file
        enable = (!allOff && docData.outputType == .Classification && docData.inputFormat != .ImagesInFolders)
        labelFile.isEnabled = enable
        labelBrowseButton.isEnabled = enable
        labelFilePath.isEnabled = enable
        
        //  Separate testing controls
        separateTestingSource.isEnabled = (!allOff && docData.trainingDataInputSource != .Generated)
        enable = (!allOff && docData.trainingDataInputSource != .Generated && docData.separateTestingSource)
        testingInputSourceBrowseButton.isEnabled = enable
        testingInputDataPath.isEnabled = enable
        enable = (enable && docData.separateOutputSource && docData.inputFormat != .ImagesInFolders)
        testingOutputSourceBrowseButton.isEnabled = enable
        testingOutputDataPath.isEnabled = enable
        
        //  Create test data controls
        enable = (!allOff && docData.trainingDataInputSource != .Generated && !docData.separateTestingSource)
        createTestDataButton.isEnabled = enable
        enable = (enable && docData.createTestDataFromTrainingData)
        fromBeginning.isEnabled = enable
        randomSamples.isEnabled = enable
        fromEnd.isEnabled = enable
        testDataPercentage.isEnabled = enable
        
        //  View data buttons
        enable = false
        if let trainingData = doc.trainingData {
            if (trainingData.trainingData.count > 0) { enable = !allOff }
        }
        viewTrainingDataButton.isEnabled = enable
        enable = false
        if let trainingData = doc.trainingData {
            if (trainingData.testingData.count > 0) { enable = !allOff }
        }
        viewTestingDataButton.isEnabled = enable
    }
    
    @IBAction func InputDimensionChanged(_ sender: NSTextField)
    {
        //  Get the dimension changed
        var dimensionIndex = -1;
        if (sender == inputDimension1) {dimensionIndex = 0}
        if (sender == inputDimension2) {dimensionIndex = 1}
        if (sender == inputDimension3) {dimensionIndex = 2}
        if (sender == inputDimension4) {dimensionIndex = 3}
        if (dimensionIndex < 0) {return}
        
        //  Validate the dimension
        let newDimension = sender.integerValue
        if (newDimension < 1 || newDimension > 1000000) { return }
        
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        
        //  Make sure the dimension changed
        if (doc.docData.inputDimensions[dimensionIndex] == newDimension) { return }
        
        //  Set the dimension
        doc.setInputDimension(index: dimensionIndex, newDimension: newDimension)
        
        //  Input changed, invalidate the training data
        invalidateTrainingData(doc: doc)
        
        //  If dimension 2 or 3 changed, update the split flag
        let canSplit = (doc.docData.inputDimensions[2] > 1 || doc.docData.inputDimensions[3] > 1)
        splitChannelsButton.isEnabled = canSplit
        if (!canSplit && doc.docData.splitChannelsIntoFlows) {
            doc.unsplitFlows()
        }
    }
    
    @IBAction func onSplitChannelsChanged(_ sender: Any) {
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        
        //  If splitting and not 10.15 or later, warn the user training is not implemented
        if #available(OSX 10.15, *) {
            //  Get the value
            doc.docData.splitChannelsIntoFlows = (splitChannelsButton.state == .on)
            
            //  Set the split state
            setSplitState(split: (splitChannelsButton.state == .on))
        }
        else {
            if (splitChannelsButton.state == .on) {
                let alert = NSAlert()
                alert.addButton(withTitle: "Continue")
                alert.addButton(withTitle: "Cancel")
                alert.messageText = "Training Not Available for Split Networks"
                alert.informativeText = "Training for multiple flows is only available in Mac OS 10.15 and later"
                alert.alertStyle = .warning
                alert.beginSheetModal(for: self.view.window!) { returnCode in
                    if (returnCode == .alertFirstButtonReturn) {
                        //  Get the value
                        doc.docData.splitChannelsIntoFlows = (self.splitChannelsButton.state == .on)
                        
                        //  Set the split state
                        self.setSplitState(split: (self.splitChannelsButton.state == .on))
                    }
                    else {
                        self.splitChannelsButton.state = .off
                     }
                }
            }
        }
    }
    
    func setSplitState(split: Bool)
    {
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        
        //  If not split, split
        if (doc.docData.splitChannelsIntoFlows) {
            doc.splitFlows()
        }
            
            //  If split before, now unsplit
        else {
            doc.unsplitFlows()
        }
    }
    
    func invalidateTrainingData(doc: Document)
    {
        doc.trainingData = nil
        numSamples.stringValue = ""
        numTestingSamples.stringValue = ""
    }
    
    @IBAction func OutputDimensionChanged(_ sender: NSTextField)
    {
        //  Get the dimension changed
        var dimensionIndex = -1;
        if (sender == outputDimension1) {dimensionIndex = 0}
        if (sender == outputDimension2) {dimensionIndex = 1}
        if (sender == outputDimension3) {dimensionIndex = 2}
        if (sender == outputDimension4) {dimensionIndex = 3}
        if (dimensionIndex < 0) {return}
        
        //  Validate the dimension
        let newDimension = sender.integerValue
        if (newDimension < 1 || newDimension > 1000000) { return }
        
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        
        //  Make sure the dimension changed
        if (doc.docData.outputDimensions[dimensionIndex] == newDimension) { return }

        //  Set the dimension
        doc.setOutputDimension(index: dimensionIndex, newDimension: newDimension)
        
        //  Output changed, invalidate the training data
        invalidateTrainingData(doc: doc)
    }
    
    @IBAction func sourceTypeChanged(_ sender: NSButton) {
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        
        switch (sender.tag) {
        case 2:
            doc.docData.trainingDataInputSource = .EnclosingFolder

        case 3:
            doc.docData.trainingDataInputSource = .File

        default:
            doc.docData.trainingDataInputSource = .Generated
            doc.docData.separateOutputSource = false
            doc.docData.separateTestingSource = false
        }
        
        //  Update controls
        setControlState()
        
        //  Source type changed, invalidate the training data
        invalidateTrainingData(doc: doc)
    }
    
    @IBAction func sourceURLChanged(_ sender: NSPathControl) {
        
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        
        doc.docData.trainingInputDataURL = sender.url
        
        //  Source changed, invalidate the training data
        invalidateTrainingData(doc: doc)
    }
    
    
    @IBAction func onBrowseForSource(_ sender: Any) {
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }

        //  Activate an OpenPanel
        let oOpenPanel = NSOpenPanel()
        let sDocumentPath = "~/Documents" as NSString
        oOpenPanel.directoryURL = URL(fileURLWithPath: sDocumentPath.expandingTildeInPath)
        oOpenPanel.canChooseDirectories = (doc.docData.trainingDataInputSource == .EnclosingFolder)
        oOpenPanel.beginSheetModal(for: view.window!) { result in
            if (result == .OK) {
                doc.docData.trainingInputDataURL = oOpenPanel.url
                self.trainingInputDataPath.url = oOpenPanel.url
                
                //  Source changed, invalidate the training data
                self.invalidateTrainingData(doc: doc)
            }
        }
    }
    
    @IBAction func onInputFormatChanged(_ sender: NSButton) {
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        
        switch (sender.tag) {
        case 1:
            doc.docData.inputFormat = .FixedColumns
            
        case 2:
            doc.docData.inputFormat = .CommaSeparated
            
        case 3:
            doc.docData.inputFormat = .SpaceDelimited
            
        case 4:
            doc.docData.inputFormat = .ImagesInFolders
            doc.docData.separateOutputSource = false
            
        default:
            doc.docData.inputFormat = .Binary
        }
        
        //  Input format changed, invalidate the training data
        invalidateTrainingData(doc: doc)
        
        //  Enable/disable controls needed
        setControlState()
    }
    
    @IBAction func onSetFormat(_ sender: Any) {
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        
        //  Get an instance of the Data Parser sheet
        let storyboard = NSStoryboard(name: "DataParser", bundle: nil)
        let controller = storyboard.instantiateController(withIdentifier: "Data Parser") as! NSWindowController
        let dataParserViewController = controller.contentViewController as! DataParserViewController
        if let parser = doc.docData.inputDataParser {
            dataParserViewController.parser = parser
        }
        else {
            dataParserViewController.parser = DataParser()
        }
        dataParserViewController.textEntry = (doc.docData.inputFormat != .Binary)
        
        //  Activate the sheet to load the data
        NSApplication.shared.mainWindow!.beginSheet(controller.window!, completionHandler:{(returnCode:NSApplication.ModalResponse) -> Void in
            //  Set the input data parser, if successfully formatted
            if (returnCode == .OK) {
                doc.docData.inputDataParser = dataParserViewController.parser
                
                //  Input format changed, invalidate the training data
                self.invalidateTrainingData(doc: doc)
            }
            
           //  Remove the sheet
            controller.window!.orderOut(self)
        })
    }
    
    @IBAction func onSeperateOutputSourceChanged(_ sender: Any) {
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        
        //  Set the flag in the document
        doc.docData.separateOutputSource = (seperateOutputSource.state == .on)
        if (doc.docData.separateOutputSource) { doc.docData.createTestDataFromTrainingData = false }
        
        //  Enable/disable controls needed for a separate output source
        setControlState()
    }
    
    @IBAction func onOutputSourceTypeChanged(_ sender: NSButton) {
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        
        switch (sender.tag) {
        case 2:
            doc.docData.trainingDataOutputSource = .EnclosingFolder
            
        default:
            doc.docData.trainingDataOutputSource = .File
        }
        
        //  Source type changed, invalidate the training data
        invalidateTrainingData(doc: doc)

        //  Enable/disable controls
        setControlState()
    }
    
    @IBAction func onOutputSourceURLChanged(_ sender: NSPathControl) {
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        
        doc.docData.trainingOutputDataURL = sender.url
        
        //  Source changed, invalidate the training data
        invalidateTrainingData(doc: doc)
    }
    
    @IBAction func onBrowseForOutputSource(_ sender: NSButton) {
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        
        //  Activate an OpenPanel
        let oOpenPanel = NSOpenPanel()
        let sDocumentPath = "~/Documents" as NSString
        oOpenPanel.directoryURL = URL(fileURLWithPath: sDocumentPath.expandingTildeInPath)
        oOpenPanel.canChooseDirectories = (doc.docData.trainingDataOutputSource == .EnclosingFolder)
        oOpenPanel.beginSheetModal(for: view.window!) { result in
            if (result == .OK) {
                doc.docData.trainingOutputDataURL = oOpenPanel.url
                self.trainingOutputDataPath.url = oOpenPanel.url
                
                //  Source changed, invalidate the training data
                self.invalidateTrainingData(doc: doc)
            }
        }
    }
    
    @IBAction func onOutputFormatChanged(_ sender: NSButton) {
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        
        switch (sender.tag) {
        case 1:
            doc.docData.outputFormat = .FixedColumns
            
        case 2:
            doc.docData.outputFormat = .CommaSeparated
            
        case 3:
            doc.docData.outputFormat = .SpaceDelimited
            
         default:
            doc.docData.outputFormat = .Binary
        }
        
        //  OUtput format changed, invalidate the training data
        invalidateTrainingData(doc: doc)
    }
    
    @IBAction func onSetOutputFormat(_ sender: NSButton) {
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        
        //  Get an instance of the Data Parser sheet
        let storyboard = NSStoryboard(name: "DataParser", bundle: nil)
        let controller = storyboard.instantiateController(withIdentifier: "Data Parser") as! NSWindowController
        let dataParserViewController = controller.contentViewController as! DataParserViewController
        if let parser = doc.docData.outputDataParser {
            dataParserViewController.parser = parser
        }
        else {
            dataParserViewController.parser = DataParser()
        }
        dataParserViewController.textEntry = (doc.docData.outputFormat != .Binary)

        //  Activate the sheet to load the data
        NSApplication.shared.mainWindow!.beginSheet(controller.window!, completionHandler:{(returnCode:NSApplication.ModalResponse) -> Void in
            //  Set the output data parser, if successfully formatted
            if (returnCode == .OK) {
                doc.docData.outputDataParser = dataParserViewController.parser
                
                //  Output format changed, invalidate the training data
                self.invalidateTrainingData(doc: doc)
            }
            
            //  Remove the sheet
            controller.window!.orderOut(self)
        })
    }
    
    @IBAction func onOutputTypeChanged(_ sender: NSButton) {
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        
        switch (sender.tag) {
        case 1:
            doc.outputType = .Classification

                        
        default:
            doc.outputType = .Regression
            doc.docData.separateLabelFile = false
        }
        
        //  Update the controls
        setControlState()
    }
    
    @IBAction func onUseLabelFileChanged(_ sender: Any) {
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        
        //  Set the flag in the document
        doc.docData.separateLabelFile = (labelFile.state == .on)
        
        //  Update the controls
        setControlState()
    }
    
    @IBAction func onLabelURLChanged(_ sender: NSPathControl) {
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        
        doc.docData.labelFileURL = sender.url
        
        //  Label file changed, invalidate the training data
        invalidateTrainingData(doc: doc)
    }
    
    @IBAction func onBrowseForLabelFile(_ sender: NSButton) {
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        
        //  Activate an OpenPanel
        let oOpenPanel = NSOpenPanel()
        let sDocumentPath = "~/Documents" as NSString
        oOpenPanel.directoryURL = URL(fileURLWithPath: sDocumentPath.expandingTildeInPath)
        oOpenPanel.beginSheetModal(for: view.window!) { result in
            if (result == .OK) {
                doc.docData.labelFileURL = oOpenPanel.url
                self.labelFilePath.url = oOpenPanel.url
                
                //  Source changed, invalidate the training data
                self.invalidateTrainingData(doc: doc)
            }
        }
    }

    @IBAction func onUseSeparateTestingSourceChanged(_ sender: Any) {
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        
        //  Set the flag in the document
        doc.docData.separateTestingSource = (separateTestingSource.state == .on)
        
        //  Update the controls
        setControlState()
        
        //  Testing source changed, invalidate the training data
        invalidateTrainingData(doc: doc)
    }

    @IBAction func onInputTestingSourceFileChanged(_ sender: NSPathControl) {
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        
        doc.docData.testingInputDataURL = sender.url
        
        //  Testing source changed, invalidate the training data
        invalidateTrainingData(doc: doc)
    }
    
    @IBAction func onBrowseForInputTestingSource(_ sender: Any) {
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        
        //  Activate an OpenPanel
        let oOpenPanel = NSOpenPanel()
        let sDocumentPath = "~/Documents" as NSString
        oOpenPanel.directoryURL = URL(fileURLWithPath: sDocumentPath.expandingTildeInPath)
        oOpenPanel.canChooseDirectories = (doc.docData.trainingDataInputSource == .EnclosingFolder)
        oOpenPanel.beginSheetModal(for: view.window!) { result in
            if (result == .OK) {
                doc.docData.testingInputDataURL = oOpenPanel.url
                self.testingInputDataPath.url = oOpenPanel.url
                
                //  Source changed, invalidate the training data
                self.invalidateTrainingData(doc: doc)
            }
        }
    }
    
    @IBAction func onOutputTestingSourceFileChanged(_ sender: NSPathControl) {
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        
        doc.docData.testingOutputDataURL = sender.url
        
        //  Testing output file changed, invalidate the training data
        invalidateTrainingData(doc: doc)
    }
    
    @IBAction func onBrowseForOutputTestingSource(_ sender: Any) {
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        
        //  Activate an OpenPanel
        let oOpenPanel = NSOpenPanel()
        let sDocumentPath = "~/Documents" as NSString
        oOpenPanel.directoryURL = URL(fileURLWithPath: sDocumentPath.expandingTildeInPath)
        oOpenPanel.canChooseDirectories = (doc.docData.trainingDataOutputSource == .EnclosingFolder)
        oOpenPanel.beginSheetModal(for: view.window!) { result in
            if (result == .OK) {
                doc.docData.testingOutputDataURL = oOpenPanel.url
                self.testingOutputDataPath.url = oOpenPanel.url
                
                //  Source changed, invalidate the training data
                self.invalidateTrainingData(doc: doc)
            }
        }
    }
    
    @IBAction func onCreateTestDataChanged(_ sender: NSButton) {
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        
        doc.docData.createTestDataFromTrainingData = (sender.state == .on)
        
        //  Configuration changed, invalidate the training data
        invalidateTrainingData(doc: doc)

        //  Update the controls
        setControlState()
    }
    
    @IBAction func onCreateTestDataSourceChanged(_ sender: NSButton) {
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        
        doc.docData.testDataSourceLocation = TestDataSourceLocation(rawValue: sender.tag)!
        
        //  Configuration changed, invalidate the training data
        invalidateTrainingData(doc: doc)
    }
    
    @IBAction func onCreateTestDataPercentageChanged(_ sender: NSTextField) {
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        
        //  Get the new value
        var percentage = sender.floatValue
        if (percentage <= 0.0) {
            createTestDataButton.state = .off
        }
        if (percentage > 1.0) { percentage = 1.0 }
        doc.docData.testDataPercentage = percentage
        
        //  Configuration changed, invalidate the training data
        invalidateTrainingData(doc: doc)

        //  Update the controls
        setControlState()
    }
    
    
    @IBAction func onLoadTraining(_ sender: Any) {
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        
        //  If already loading something, stop when we can
        if (continueLoading) {
            continueLoading = false
            doc.abortLoading()
            return
        }
        
        //  Force a new load
        invalidateTrainingData(doc: doc)

        //  Get a dispatch queue to do this in
        let queue = DispatchQueue(label: "loading")

        //  Change the button to 'Stop'
        continueLoading = true
        loadButton.title = "Stop"
        
        //  Turn off all other controls, so data format isn't changed while loading
        setControlState(allOff: true)
        
       //  Load the data
        queue.async {
            doc.loadTrainingData()
        }
        
        queue.async {
            self.doneLoading()
        }
        
        //  Start a monitoring timer
        updateTimer = DispatchSource.makeTimerSource(flags: DispatchSource.TimerFlags(rawValue: 0), queue: DispatchQueue.main)
        updateTimer!.schedule(deadline: DispatchTime.now(), repeating: 0.5)
        updateTimer!.setEventHandler(handler: updateLoadProgress)
        updateTimer!.resume()
     }
    
    func doneLoading()
    {
        //  Change the button back to 'Load' (on main thread)
        DispatchQueue.main.async {
            self.loadButton.title = "Load"
            self.continueLoading = false
            self.setControlState()
            
            guard let doc = self.view.window?.windowController?.document as? Document else { return }
            if doc.trainingData == nil {
                let alert = NSAlert()
                if let error = doc.docData.loadError {
                    alert.addButton(withTitle: "OK")
                    alert.messageText = error
                    alert.informativeText = "Error loading training data"
                    alert.alertStyle = .warning
                    alert.beginSheetModal(for: self.view.window!) { returnCode in
                    }
                }
            }

            else {
                //  Update the sample counts
                let samples = doc.numTrainingSamples
                if (samples == 0) {
                    self.numSamples.stringValue = ""
                }
                else {
                    self.numSamples.integerValue = samples
                }
                let testingSamples = doc.numTestingSamples
                if (testingSamples == 0) {
                    self.numTestingSamples.stringValue = ""
                }
                else {
                    self.numTestingSamples.integerValue = testingSamples
                }
                
                //  Update the loading status
                self.loadStatusField.stringValue = doc.docData.loadingStatus
            }
        }
    }
    
    func updateLoadProgress()
    {
        //  If we stopped loading, stop the timer
        if (!continueLoading) {
            if let timer = updateTimer {
                timer.cancel()
                updateTimer = nil
            }
        }
        
        DispatchQueue.main.async {
            guard let doc = self.view.window?.windowController?.document as? Document else { return }
            var samples = doc.docData.loadedTrainingSamples.value
            if (doc.trainingData != nil) { samples = doc.numTrainingSamples }
            if (samples == 0) {
                self.numSamples.stringValue = ""
            }
            else {
                self.numSamples.integerValue = samples
            }
            var testingSamples = doc.docData.loadedTestingSamples.value
            if (doc.trainingData != nil) { testingSamples = doc.numTestingSamples }
            if (testingSamples == 0) {
                self.numTestingSamples.stringValue = ""
            }
            else {
                self.numTestingSamples.integerValue = testingSamples
            }
            self.loadStatusField.stringValue = doc.docData.loadingStatus
         }
    }
    
    @IBAction func onViewTrainingData(_ sender: Any) {
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        
        let storyboard = NSStoryboard(name: "DataAsImage", bundle: nil)
        let controller = storyboard.instantiateController(withIdentifier: "Data As Image") as! NSWindowController
        let dataAsImageViewController = controller.contentViewController as! DataAsImageViewController
        dataAsImageViewController.data = doc.trainingData?.trainingData
        dataAsImageViewController.results = nil
        dataAsImageViewController.dataInputDimensions = doc.trainingData?.inputDimensions
        dataAsImageViewController.dataOutputDimensions = doc.trainingData?.outputDimensions
        dataAsImageViewController.regression = (doc.outputType == .Regression)

        //  Activate the sheet to load the data
        NSApplication.shared.mainWindow!.beginSheet(controller.window!, completionHandler:{(returnCode:NSApplication.ModalResponse) -> Void in
            //  Remove the sheet
            controller.window!.orderOut(self)
        })
    }
    
    @IBAction func onViewTestingData(_ sender: Any) {
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        
        let storyboard = NSStoryboard(name: "DataAsImage", bundle: nil)
        let controller = storyboard.instantiateController(withIdentifier: "Data As Image") as! NSWindowController
        let dataAsImageViewController = controller.contentViewController as! DataAsImageViewController
        dataAsImageViewController.data = doc.trainingData?.testingData
        dataAsImageViewController.results = nil
        dataAsImageViewController.dataInputDimensions = doc.trainingData?.inputDimensions
        dataAsImageViewController.dataOutputDimensions = doc.trainingData?.outputDimensions
        dataAsImageViewController.regression = (doc.outputType == .Regression)

        //  Activate the sheet to load the data
        NSApplication.shared.mainWindow!.beginSheet(controller.window!, completionHandler:{(returnCode:NSApplication.ModalResponse) -> Void in
            //  Remove the sheet
            controller.window!.orderOut(self)
        })
    }
    
    override func viewDidAppear()
    {
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        
        //  Set the dimension text fields
        inputDimension1.integerValue = doc.docData.inputDimensions[0]
        inputDimension2.integerValue = doc.docData.inputDimensions[1]
        inputDimension3.integerValue = doc.docData.inputDimensions[2]
        inputDimension4.integerValue = doc.docData.inputDimensions[3]
        outputDimension1.integerValue = doc.docData.outputDimensions[0]
        outputDimension2.integerValue = doc.docData.outputDimensions[1]
        outputDimension3.integerValue = doc.docData.outputDimensions[2]
        outputDimension4.integerValue = doc.docData.outputDimensions[3]
        
        //  Set the input source
        switch (doc.docData.trainingDataInputSource) {
        case .Generated:
            generatedInput.state = .on
            
        case .EnclosingFolder:
            folderInput.state = .on

        case .File:
            fileInput.state = .on
        }
        trainingInputDataPath.url = doc.docData.trainingInputDataURL
        
        //  Set the input format
        switch (doc.docData.inputFormat) {
        case .FixedColumns:
            fixedColumn.state = .on
        case .CommaSeparated:
            commaSeparated.state = .on
        case .SpaceDelimited:
            spaceDelimited.state = .on
        case .ImagesInFolders:
            imageInFolders.state = .on
        case .Binary:
            binaryStyle.state = .on
        }
        
        //  Set the seperate output source checkbox
        seperateOutputSource.state = doc.docData.separateOutputSource ? .on : .off
        
        //  Set the output source
        switch (doc.docData.trainingDataOutputSource) {
        case .EnclosingFolder:
            folderOutput.state = .on
            
        default:
            fileOutput.state = .on
        }
        trainingOutputDataPath.url = doc.docData.trainingOutputDataURL

        //  Set the output format
        switch (doc.docData.outputFormat) {
        case .FixedColumns:
            fixedColumnOutput.state = .on
        case .CommaSeparated:
            commaSeparatedOutput.state = .on
        case .SpaceDelimited:
            spaceDelimitedOutput.state = .on
        default:
            binaryStyleOutput.state = .on
        }

        //  Set the seperate label file checkbox
        labelFile.state = doc.docData.separateLabelFile ? .on : .off
        labelFilePath.url = doc.docData.labelFileURL

        //  Set the seperate testing source checkbox
        separateTestingSource.state = doc.docData.separateTestingSource ? .on : .off
        testingInputDataPath.url = doc.docData.testingInputDataURL
        testingOutputDataPath.url = doc.docData.testingOutputDataURL

        //  Set the output type
        switch (doc.outputType) {
        case .Classification:
            outputClassification.state = .on
            
        case .Regression:
            outputRegression.state = .on
        }
        
        //  Set the create test data controls
        createTestDataButton.state = doc.docData.createTestDataFromTrainingData ? .on : .off
        switch (doc.docData.testDataSourceLocation) {
        case .Beginning:
            fromBeginning.state = .on
        case .Random:
            randomSamples.state = .on
        case.End:
            fromEnd.state = .on
        }
        testDataPercentage.floatValue = doc.docData.testDataPercentage

        //  Enable controls as needed
        setControlState()
    }
}

