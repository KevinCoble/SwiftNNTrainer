//
//  NetworkViewController.swift
//  SwiftNNTrainer
//
//  Created by Kevin Coble on 2/8/19.
//  Copyright © 2019 Kevin Coble. All rights reserved.
//

import Cocoa
import MetalPerformanceShaders
import MetalKit
import SceneKit

enum UseKernel {
    case no
    case oddOnly
    case anyValue
}

class NetworkViewController: NSViewController
{
    
    @IBOutlet weak var flowsTable: NSTableView!
    @IBOutlet weak var setOutputFlowButton: NSButton!
    @IBOutlet weak var duplicateFlowButton: NSButton!
    @IBOutlet weak var layersTable: NSTableView!
    @IBOutlet weak var network3DView: Network3DView!
    @IBOutlet weak var networkValidity: NSTextField!
    @IBOutlet weak var numberParameters: NSTextField!
    @IBOutlet weak var layerType: NSPopUpButton!
    @IBOutlet weak var layerSubType: NSPopUpButton!
    @IBOutlet weak var channelsLabel: NSTextField!
    @IBOutlet weak var channels: NSTextField!
    @IBOutlet weak var channelsStepper: NSStepper!
    @IBOutlet weak var useBiasTerms: NSButton!
    @IBOutlet weak var additionalDataButton: NSButton!
    @IBOutlet weak var kernelWidthLabel: NSTextField!
    @IBOutlet weak var kernelWidth: NSTextField!
    @IBOutlet weak var kernelWidthStepper: NSStepper!
    @IBOutlet weak var kernelHeightLabel: NSTextField!
    @IBOutlet weak var kernelHeight: NSTextField!
    @IBOutlet weak var kernelHeightStepper: NSStepper!
    @IBOutlet weak var strideXLabel: NSTextField!
    @IBOutlet weak var strideX: NSTextField!
    @IBOutlet weak var strideXStepper: NSStepper!
    @IBOutlet weak var strideYLabel: NSTextField!
    @IBOutlet weak var strideY: NSTextField!
    @IBOutlet weak var strideYStepper: NSStepper!
    @IBOutlet weak var paddingDescription: NSTextField!
    @IBOutlet weak var paddingButton: NSButton!
    @IBOutlet weak var addLayerButton: NSButton!
    @IBOutlet weak var updateLayerButton: NSButton!
    @IBOutlet weak var insertLayerButton: NSButton!
    @IBOutlet weak var deleteLayerButton: NSButton!
    @IBOutlet weak var lossFunctionType: NSPopUpButton!
    @IBOutlet weak var currentRuleLabel: NSTextField!
    @IBOutlet weak var currentRuleField: NSTextField!
    @IBOutlet weak var setUpdateRuleButton: NSButton!
    
    var network3DScene = Network3DScene()

    var currentFlow = -1
    var currentLayer = Layer()
    var kernelEntryType : UseKernel = .anyValue

    override func viewDidLoad() {
        super.viewDidLoad()
        
        //  Allow user interaction with the 3D scene
        network3DView.allowsCameraControl = true
        network3DView.controller = self
        
        //  Set up the network view
        network3DView.scene = network3DScene
        network3DView.backgroundColor = NSColor.darkGray
        network3DView.autoenablesDefaultLighting = false
        network3DView.pointOfView = network3DScene.cameraNode
//        network3DView.debugOptions = [SCNDebugOptions.renderAsWireframe, .showSkeletons]
        
        //  Set up the controls
        setControls()
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
            flowsTable.reloadData()
            layersTable.reloadData()
        }
    }
    
    func setControls()
    {
        //  Set the controls to the layer values
        kernelWidth.integerValue = currentLayer.kernelWidth
        kernelWidthStepper.integerValue = currentLayer.kernelWidth
        kernelHeight.integerValue = currentLayer.kernelHeight
        kernelHeightStepper.integerValue = currentLayer.kernelHeight
        layerType.selectItem(withTag: currentLayer.type.rawValue)
        onLayerTypeChange(layerType)
        layerSubType.selectItem(withTag: currentLayer.subType)
        setAdditionalData()
        channels.integerValue = currentLayer.numChannels
        channelsStepper.integerValue = currentLayer.numChannels
        useBiasTerms.state = currentLayer.useBiasTerms ? .on : .off
        strideX.integerValue = currentLayer.strideX
        strideXStepper.integerValue = currentLayer.strideX
        strideY.integerValue = currentLayer.strideY
        strideYStepper.integerValue = currentLayer.strideY
        currentRuleField.stringValue = currentLayer.getUpdateRuleString()
        paddingDescription.stringValue = currentLayer.paddingDescription()
    }
    
    func setAdditionalData()
    {
        let additionalData = currentLayer.getAdditionalDataInfo()
        additionalDataButton.isEnabled = (additionalData.count > 0)
    }
    
    func reloadTables(keepFlowSelection: Bool, keepLayerSelection: Bool)
    {
        //  Reload the flow table
        let rowsSelected = flowsTable.selectedRowIndexes
        let layerRowsSelected = layersTable.selectedRowIndexes
        flowsTable.reloadData()
        if (keepFlowSelection) {
            flowsTable.selectRowIndexes(rowsSelected, byExtendingSelection: false)
        }
        else {
            flowsTable.deselectAll(self)
            currentFlow = -1
        }
        
        //  Reload the layer table
         layersTable.reloadData()
        if (keepLayerSelection) {
            layersTable.selectRowIndexes(layerRowsSelected, byExtendingSelection: false)
        }
        else {
            layersTable.deselectAll(self)
            guard let doc = view.window?.windowController?.document as? Document else { return }
            doc.resetLayerSelection()
        }
    }
    
    @IBAction func onSetFlowAsOutput(_ sender: Any) {
    }
    
    @IBAction func onDuplicateFlow(_ sender: Any) {
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        
        if (currentFlow < 0 || currentFlow >= doc.docData.flows.count) { return }
        
         //  Get an instance of the Duplicate Flow Data sheet
        let storyboard = NSStoryboard(name: "DuplicateFlow", bundle: nil)
        let controller = storyboard.instantiateController(withIdentifier: "Duplicate Flow") as! NSWindowController
        let duplicateFlowViewController = controller.contentViewController as! DuplicateFlowViewController
        
        duplicateFlowViewController.docData = doc.docData
        duplicateFlowViewController.fromFlowIndex = currentFlow
        
        //  Activate the sheet to load the data
        NSApplication.shared.mainWindow!.beginSheet(controller.window!, completionHandler:{(returnCode:NSApplication.ModalResponse) -> Void in
            //  Update the flow and layer tables
            if (returnCode == .OK) {
                //  Update the flow sizes
                doc.docData.updateFlowDimensions()
                
                //  Reload the tables
                self.reloadTables(keepFlowSelection: true, keepLayerSelection: false)
            }
            
            //  Remove the sheet
            controller.window!.orderOut(self)
        })
    }
    
    @IBAction func onShowXYBlocksChanged(_ sender: NSButton) {
        network3DScene.use_XxY_for_1x1xN = (sender.state == .on)
        
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }

        //  Update the 3D view
        network3DScene.setFromDocument(document: doc.docData)
    }
    
    @IBAction func onOutputBlockScaleChanged(_ sender: NSSlider) {
        let newScale : CGFloat = CGFloat(sender.floatValue * 0.01)
        network3DScene.outputBlockScale = newScale
        
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        
        //  Update the 3D view
        network3DScene.setFromDocument(document: doc.docData)
    }
    
    @IBAction func onLayerTypeChange(_ sender: NSPopUpButton) {
        
        if let type = LayerType(rawValue: sender.selectedTag()) {
            //  Remove the previous sub-type items
            layerSubType.removeAllItems()

            //  See if we need to initialize additional data
            if (currentLayer.type != type) {
                currentLayer.type = type
                currentLayer.subType = 1
                currentLayer.initializeAdditionalDataInfo()
            }

            //  Fill the subtype selection and change the 'channels' to 'neurons' for fully connected layers
            switch (type) {
            case .Convolution:
                var subType = 1
                while (true) {
                    if let subtype = ConvolutionSubType(rawValue: subType) {
                        layerSubType.addItem(withTitle: subtype.subTypeString)
                    }
                    else {
                        break
                    }
                    subType += 1
                }
                configureControls(channelsLabelString: "Channels", useBias: true, useKernel: .oddOnly, useStride: true, useUpdate: true)

            case .Pooling:
                var subType = 1
                while (true) {
                    if let subtype = PoolingSubType(rawValue: subType) {
                        layerSubType.addItem(withTitle: subtype.subTypeString)
                    }
                    else {
                        break
                    }
                    subType += 1
                }
                configureControls(channelsLabelString: nil, useBias: false, useKernel: .anyValue, useStride: true, useUpdate: false)
                
            case .FullyConnected:
                var subType = 1
                while (true) {
                    if let subtype = FullyConnectedSubType(rawValue: subType) {
                        layerSubType.addItem(withTitle: subtype.subTypeString)
                    }
                    else {
                        break
                    }
                    subType += 1
                }
                configureControls(channelsLabelString: "Neurons:", useBias: true, useKernel: .no, useStride: false, useUpdate: true)
                
            case .Neuron:
                var subType = 1
                while (true) {
                    if let subtype = NeuronSubType(rawValue: subType) {
                        layerSubType.addItem(withTitle: subtype.subTypeString)
                    }
                    else {
                        break
                    }
                    subType += 1
                }
                configureControls(channelsLabelString: nil, useBias: false, useKernel: .no, useStride: false, useUpdate: false)
                
            case .SoftMax:
                var subType = 1
                while (true) {
                    if let subtype = SoftMaxSubType(rawValue: subType) {
                        layerSubType.addItem(withTitle: subtype.subTypeString)
                    }
                    else {
                        break
                    }
                    subType += 1
                }
                configureControls(channelsLabelString: nil, useBias: false, useKernel: .no, useStride: false, useUpdate: false)
                
            case .Normalization:
                var subType = 1
                while (true) {
                    if let subtype = NormalizationSubType(rawValue: subType) {
                        layerSubType.addItem(withTitle: subtype.subTypeString)
                    }
                    else {
                        break
                    }
                    subType += 1
                }
                configureControls(channelsLabelString: nil, useBias: false, useKernel: .no, useStride: false, useUpdate: false)
                
            case .UpSampling:
                var subType = 1
                while (true) {
                    if let subtype = UpSamplingSubType(rawValue: subType) {
                        layerSubType.addItem(withTitle: subtype.subTypeString)
                    }
                    else {
                        break
                    }
                    subType += 1
                }
                configureControls(channelsLabelString: nil, useBias: false, useKernel: .no, useStride: false, useUpdate: false)
                
            case .DropOut:
                var subType = 1
                while (true) {
                    if let subtype = DropOutSubType(rawValue: subType) {
                        layerSubType.addItem(withTitle: subtype.subTypeString)
                    }
                    else {
                        break
                    }
                    subType += 1
                }
                configureControls(channelsLabelString: nil, useBias: false, useKernel: .no, useStride: false, useUpdate: false)

            default:
                layerSubType.addItem(withTitle: "*Not Implemented*")
                configureControls(channelsLabelString: nil, useBias: false, useKernel: .no, useStride: false, useUpdate: false)
            }
            if (currentLayer.subType < 1) {
                layerSubType.selectItem(at: 0)
            }
            else {
                layerSubType.selectItem(at: currentLayer.subType-1)
            }
        }
    }
    
    @IBAction func onLayerSubTypeChange(_ sender: NSPopUpButton) {
        let title = layerSubType.titleOfSelectedItem
        if (title!.starts(with: "*")) {
            currentLayer.subType = -1
            return
        }

        //  See if we need to initialize additional data
        let initialize = (currentLayer.subType != layerSubType.indexOfSelectedItem + 1)
        
        currentLayer.subType = layerSubType.indexOfSelectedItem + 1
        if (initialize) { currentLayer.initializeAdditionalDataInfo() }
        setAdditionalData()
    }
    
    @IBAction func onChannelTextChanged(_ sender: NSTextField) {
        //  Set the stepper from the text field
        if (channelsStepper.integerValue == sender.integerValue) {return}       //  Stop loops
        channelsStepper.integerValue = Int(sender.integerValue)
        currentLayer.numChannels = Int(sender.integerValue)
    }
    @IBAction func onChannelStepperChanged(_ sender: NSStepper) {
        //  Set the text field from the stepper
        if (channels.integerValue == sender.integerValue) {return}       //  Stop loops
        channels.integerValue = Int(sender.integerValue)
        currentLayer.numChannels = Int(sender.integerValue)
    }
    
    @IBAction func onUseBiasTermsChanged(_ sender: NSButton) {
        currentLayer.useBiasTerms = (useBiasTerms.state == .on)
    }
    
    @IBAction func onAdditionalData(_ sender: Any) {
        //  Get an instance of the Additional Data sheet
        let storyboard = NSStoryboard(name: "AdditionalData", bundle: nil)
        let controller = storyboard.instantiateController(withIdentifier: "Additional Data") as! NSWindowController
        let additionalDataViewController = controller.contentViewController as! AdditionalDataViewController
        
        additionalDataViewController.infoDescription = currentLayer.getAdditionalDataInfo()
        additionalDataViewController.currentValues = currentLayer.additionalData

        //  Activate the sheet to load the data
        NSApplication.shared.mainWindow!.beginSheet(controller.window!, completionHandler:{(returnCode:NSApplication.ModalResponse) -> Void in
            //  Set the output data parser, if successfully formatted
            if (returnCode == .OK) {
                self.currentLayer.additionalData = additionalDataViewController.currentValues!
            }
            
            //  Remove the sheet
            controller.window!.orderOut(self)
        })
    }
    
    @IBAction func onKernelWidthChanged(_ sender: NSTextField) {
        //  Limit kernel size to odd values
        var value = sender.integerValue
        if (kernelEntryType == .oddOnly) {
            if ((value % 2) == 0) {
                value -= 1
                if (value < 1) { value = 1 }
                sender.integerValue = value
            }
        }
        //  Set the stepper from the text field
        if (kernelWidthStepper.integerValue == value) {return}       //  Stop loops
        kernelWidthStepper.integerValue = value
        
        currentLayer.kernelWidth = value
    }
    @IBAction func onKernelWidthStepperChanged(_ sender: NSStepper) {
        //  Set the text field from the stepper
        if (kernelWidth.integerValue == sender.integerValue) {return}       //  Stop loops
        kernelWidth.integerValue = sender.integerValue
        
        currentLayer.kernelWidth = sender.integerValue
    }
    
    @IBAction func onKernelHeightChanged(_ sender: NSTextField) {
        //  Limit kernel size to odd values
        var value = sender.integerValue
        if (kernelEntryType == .oddOnly) {
            if ((value % 2) == 0) {
                value -= 1
                if (value < 1) { value = 1 }
                sender.integerValue = value
            }
        }
        //  Set the stepper from the text field
        if (kernelHeightStepper.integerValue == value) {return}       //  Stop loops
        kernelHeightStepper.integerValue = value
        
        currentLayer.kernelHeight = value
    }
    @IBAction func onKernelHeightStepperChanged(_ sender: NSStepper) {
        //  Set the text field from the stepper
        if (kernelHeight.integerValue == sender.integerValue) {return}       //  Stop loops
        kernelHeight.integerValue = sender.integerValue
        
        currentLayer.kernelHeight = sender.integerValue
    }
    
    @IBAction func onStrideXChanged(_ sender: NSTextField) {
        //  Set the stepper from the text field
        if (strideXStepper.integerValue == sender.integerValue) {return}       //  Stop loops
        strideXStepper.integerValue = sender.integerValue
        
        currentLayer.strideX = sender.integerValue
    }
    @IBAction func onStrideXStepperChanged(_ sender: NSStepper) {
        //  Set the text field from the stepper
        if (strideX.integerValue == sender.integerValue) {return}       //  Stop loops
        strideX.integerValue = sender.integerValue
        
        currentLayer.strideX = sender.integerValue

    }
    
    @IBAction func onStrideYChanged(_ sender: NSTextField) {
        //  Set the stepper from the text field
        if (strideYStepper.integerValue == sender.integerValue) {return}       //  Stop loops
        strideYStepper.integerValue = Int(sender.integerValue)
        
        currentLayer.strideY = sender.integerValue
    }
    @IBAction func onStrideYStepperChanged(_ sender: NSStepper) {
        //  Set the text field from the stepper
        if (strideY.integerValue == sender.integerValue) {return}       //  Stop loops
        strideY.integerValue = Int(sender.integerValue)
        
        currentLayer.strideY = sender.integerValue
    }
    
    @IBAction func onSetPadding(_ sender: Any) {
        //  Get an instance of the Padding sheet
        let storyboard = NSStoryboard(name: "Padding", bundle: nil)
        let controller = storyboard.instantiateController(withIdentifier: "Padding") as! NSWindowController
        let paddingViewController = controller.contentViewController as! PaddingViewController
    
        paddingViewController.XPaddingMethod = currentLayer.XPaddingMethod
        paddingViewController.YPaddingMethod = currentLayer.YPaddingMethod
        paddingViewController.featurePaddingMethod = currentLayer.featurePaddingMethod
        paddingViewController.XOffset = currentLayer.XOffset
        paddingViewController.YOffset = currentLayer.YOffset
        paddingViewController.featureOffset = currentLayer.featureOffset
        paddingViewController.clipWidth = currentLayer.clipWidth
        paddingViewController.clipHeight = currentLayer.clipHeight
        paddingViewController.clipDepth = currentLayer.clipDepth
        paddingViewController.edgeMode = currentLayer.edgeMode
        paddingViewController.paddingConstant = currentLayer.paddingConstant

        paddingViewController.kernelX = kernelWidth.integerValue
        paddingViewController.kernelY = kernelHeight.integerValue
        paddingViewController.strideX = strideX.integerValue
        paddingViewController.strideY = strideY.integerValue

        //  Activate the sheet to load the data
        NSApplication.shared.mainWindow!.beginSheet(controller.window!, completionHandler:{(returnCode:NSApplication.ModalResponse) -> Void in
            //  Set the output data parser, if successfully formatted
            if (returnCode == .OK) {
                self.currentLayer.XPaddingMethod = paddingViewController.XPaddingMethod
                self.currentLayer.YPaddingMethod = paddingViewController.YPaddingMethod
                self.currentLayer.featurePaddingMethod = paddingViewController.featurePaddingMethod
                self.currentLayer.XOffset = paddingViewController.XOffset
                self.currentLayer.YOffset = paddingViewController.YOffset
                self.currentLayer.featureOffset = paddingViewController.featureOffset
                self.currentLayer.clipWidth = paddingViewController.clipWidth
                self.currentLayer.clipHeight = paddingViewController.clipHeight
                self.currentLayer.clipDepth = paddingViewController.clipDepth
                self.currentLayer.edgeMode = paddingViewController.edgeMode
                self.currentLayer.paddingConstant = paddingViewController.paddingConstant
                
                self.paddingDescription.stringValue = self.currentLayer.paddingDescription()
            }
            
            //  Remove the sheet
            controller.window!.orderOut(self)
        })
    }
    
    @IBAction func onSetUpdateRule(_ sender: Any) {
        //  Get an instance of the Update Rule sheet
        let storyboard = NSStoryboard(name: "UpdateRule", bundle: nil)
        let controller = storyboard.instantiateController(withIdentifier: "Update Rule") as! NSWindowController
        let updateRuleViewController = controller.contentViewController as! UpdateRuleViewController
        
        updateRuleViewController.currentUpdateRule = currentLayer.updateRule
        updateRuleViewController.currentLearningRateMultiplier = currentLayer.learningRateMultiplier
        updateRuleViewController.currentMomentumScale = currentLayer.momentumScale
        updateRuleViewController.currentUseNesterovMomentum = currentLayer.useNesterovMomentum
        updateRuleViewController.currentEpsilon = currentLayer.epsilon
        updateRuleViewController.currentBeta1 = currentLayer.beta1
        updateRuleViewController.currentBeta2 = currentLayer.beta2
        updateRuleViewController.currentTimeStep = currentLayer.timeStep
        updateRuleViewController.currentGradientRescale = currentLayer.gradientRescale
        updateRuleViewController.currentApplyGradientClipping = currentLayer.applyGradientClipping
        updateRuleViewController.currentGradientClipMax = currentLayer.gradientClipMax
        updateRuleViewController.currentGradientClipMin = currentLayer.gradientClipMin
        updateRuleViewController.currentRegularizationType = currentLayer.regularizationType
        updateRuleViewController.currentRegularizationScale = currentLayer.regularizationScale

        //  Activate the sheet to load the data
        NSApplication.shared.mainWindow!.beginSheet(controller.window!, completionHandler:{(returnCode:NSApplication.ModalResponse) -> Void in
            //  Set the output data parser, if successfully formatted
            if (returnCode == .OK) {
                //  Get the values
                self.currentLayer.updateRule = updateRuleViewController.currentUpdateRule
                self.currentLayer.learningRateMultiplier = updateRuleViewController.currentLearningRateMultiplier
                self.currentLayer.momentumScale = updateRuleViewController.currentMomentumScale
                self.currentLayer.useNesterovMomentum = updateRuleViewController.currentUseNesterovMomentum
                self.currentLayer.epsilon = updateRuleViewController.currentEpsilon
                self.currentLayer.beta1 = updateRuleViewController.currentBeta1
                self.currentLayer.beta2 = updateRuleViewController.currentBeta2
                self.currentLayer.timeStep = updateRuleViewController.currentTimeStep
                self.currentLayer.gradientRescale = updateRuleViewController.currentGradientRescale
                self.currentLayer.applyGradientClipping = updateRuleViewController.currentApplyGradientClipping
                self.currentLayer.gradientClipMax = updateRuleViewController.currentGradientClipMax
                self.currentLayer.gradientClipMin = updateRuleViewController.currentGradientClipMin
                self.currentLayer.regularizationType = updateRuleViewController.currentRegularizationType
                self.currentLayer.regularizationScale = updateRuleViewController.currentRegularizationScale
                
                //  Update the shown string
                self.currentRuleField.stringValue = self.currentLayer.getUpdateRuleString()
            }
            
            //  Remove the sheet
            controller.window!.orderOut(self)
        })
    }
    
    @IBAction func OnAddLayer(_ sender: Any)
    {
         //  Check the subtype
        if (currentLayer.subType < 0) { return }
 
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        
        //  Create the new layer
        let newLayer = Layer()
        newLayer.setFrom(layer: currentLayer)

        //  Add the layer
        doc.addLayer(toFlow: currentFlow, newLayer: newLayer)
        
        //  Update the flow sizes
        doc.docData.updateFlowDimensions()

        //  Check the network validity (could have changed data dimensions)
        networkValidity.stringValue = doc.validateNetwork()
        numberParameters.integerValue = doc.numParameters
        
        //  Reload the tables
        reloadTables(keepFlowSelection: true, keepLayerSelection: false)
        
        //  Update the 3D view
        network3DScene.setFromDocument(document: doc.docData)
    }
    
    @IBAction func onUpdateLayer(_ sender: Any) {
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        
        //  Validate the flow
        if (currentFlow < 0 || currentFlow >= doc.docData.flows.count) { return }
        
        //  Get the selection
        let row = layersTable.selectedRow
        
        if (row >= 0 && row < doc.docData.flows[currentFlow].layers.count) {
            //  Update the selected layer
            doc.updateLayer(inFlow: currentFlow, fromLayer: currentLayer, atIndex: row)
            
            //  Update the flow sizes
            doc.docData.updateFlowDimensions()
            
           //  Check the network validity (could have changed data dimensions)
            networkValidity.stringValue = doc.validateNetwork()
            numberParameters.integerValue = doc.numParameters

            //  Reload the tables
            reloadTables(keepFlowSelection: true, keepLayerSelection: true)

            //  Update the 3D view
            network3DScene.setFromDocument(document: doc.docData)
        }
    }
    
    @IBAction func onInsertLayer(_ sender: Any) {
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        
        //  Validate the flow
        if (currentFlow < 0 || currentFlow >= doc.docData.flows.count) { return }

       //  Get the selection
        let row = layersTable.selectedRow
        if (row >= 0 && row < doc.docData.flows[currentFlow].layers.count) {
            //  Create the new layer
            let newLayer = Layer()
            newLayer.setFrom(layer: currentLayer)
            
            //  Insert the layer
            doc.insertLayer(inFlow: currentFlow, newLayer: newLayer, atIndex: row)
            
            //  Update the flow sizes
            doc.docData.updateFlowDimensions()

            //  Check the network validity (could have changed data dimensions)
            networkValidity.stringValue = doc.validateNetwork()
            numberParameters.integerValue = doc.numParameters

            //  Reload the tables
            reloadTables(keepFlowSelection: true, keepLayerSelection: false)

            //  Update the 3D view
            network3DScene.setFromDocument(document: doc.docData)
        }
    }
    
    @IBAction func onDeleteLayer(_ sender: Any) {
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        
        //  Validate the flow
        if (currentFlow < 0 || currentFlow >= doc.docData.flows.count) { return }
        let flow = doc.docData.flows[currentFlow]

        //  Get the selection
        let row = layersTable.selectedRow
        if (row >= 0 && row < flow.layers.count) {
            //  Delete the selected row
            flow.layers.remove(at: row)
            
            //  Update the flow sizes
            doc.docData.updateFlowDimensions()
            
            //  Check the network validity (could have changed data dimensions)
            networkValidity.stringValue = doc.validateNetwork()
            numberParameters.integerValue = doc.numParameters

            //  Reload the tables
            reloadTables(keepFlowSelection: true, keepLayerSelection: false)

            //  Update the 3D view
            network3DScene.setFromDocument(document: doc.docData)
        }
    }
    
    func configureControls(channelsLabelString: String?, useBias: Bool, useKernel: UseKernel, useStride : Bool, useUpdate : Bool)
    {
        //  Channels/Neuron entry
        if let string = channelsLabelString {
            channelsLabel.stringValue = string
            channels.isEnabled = true
            channelsStepper.isEnabled = true
        }
        else {
            channelsLabel.stringValue = " "
            channels.isEnabled = false
            channelsStepper.isEnabled = false
        }
        
        //  Use bias terms checkbox
        useBiasTerms.isEnabled = useBias
        
        //  Kernel
        kernelWidthLabel.isEnabled = (useKernel != .no)
        kernelWidth.isEnabled = (useKernel != .no)
        kernelWidthStepper.isEnabled = (useKernel != .no)
        kernelHeightLabel.isEnabled = (useKernel != .no)
        kernelHeight.isEnabled = (useKernel != .no)
        kernelHeightStepper.isEnabled = (useKernel != .no)
        kernelEntryType = useKernel
        if (kernelEntryType == .anyValue) {
            kernelWidthStepper.increment = 1.0
            kernelHeightStepper.increment = 1.0
        }
        else if (kernelEntryType == .oddOnly) {
            kernelWidthStepper.increment = 2.0
            kernelHeightStepper.increment = 2.0
            if ((kernelWidthStepper.integerValue % 2) == 0) {
                kernelWidthStepper.integerValue += 1
                kernelWidth.integerValue = kernelWidthStepper.integerValue
                currentLayer.kernelWidth = kernelWidthStepper.integerValue
            }
            if ((kernelHeightStepper.integerValue % 2) == 0) {
                kernelHeightStepper.integerValue += 1
                kernelHeight.integerValue = kernelHeightStepper.integerValue
                currentLayer.kernelHeight = kernelHeightStepper.integerValue
            }
        }
        
        //  Stride
        strideXLabel.isEnabled = useStride
        strideX.isEnabled = useStride
        strideXStepper.isEnabled = useStride
        strideYLabel.isEnabled = useStride
        strideY.isEnabled = useStride
        strideYStepper.isEnabled = useStride
        
        //  Padding
        paddingButton.isEnabled = (useKernel != .no)
        paddingDescription.isEnabled = (useKernel != .no)
        if (useKernel == .no) { paddingDescription.stringValue = "" }

        //  Update Rule
        currentRuleLabel.isEnabled = useUpdate
        currentRuleField.isEnabled = useUpdate
        setUpdateRuleButton.isEnabled = useUpdate
    }
    
    @IBAction func onLossFunctionTypeChanged(_ sender: NSPopUpButton)
    {
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }

        //  Set the new value
        doc.docData.lossType = MPSCNNLossType(rawValue: UInt32(sender.selectedTag()))!
    }
    
    override func viewDidAppear()
    {
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        
        //  Check the network validity (could have changed data dimensions)
        networkValidity.stringValue = doc.validateNetwork()
        numberParameters.integerValue = doc.numParameters

        //  Update the loss type
        lossFunctionType.selectItem(withTag: Int(doc.docData.lossType.rawValue))
        
        //  Reload the tables
        reloadTables(keepFlowSelection: false, keepLayerSelection: false)

        //  If only one flow, start with that one selected
        if (doc.docData.flows.count == 1) {
            flowsTable.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }

        //  Update the 3D view
        network3DScene.setFromDocument(document: doc.docData)
    }

    static func dimensionsToString(dimensions : [Int]) -> String
    {
        var string = "["
        var count = dimensions.count
        while (count > 1) {
            if (dimensions[count-1] > 1) { break }
            count -= 1
        }
        if (count > 0) {
            if (count > 1) {
                for i in 0..<count-1 {
                    string += "\(dimensions[i]), "
                }
            }
            string += "\(dimensions[count-1])"
        }
        string += "]"
        
        return string
    }

    func selectLayer(inFlow: Int, atIndex: Int)
    {
        flowsTable.selectRowIndexes(IndexSet(integer: inFlow), byExtendingSelection: false)

        let indexSet = IndexSet(integer: atIndex)
        layersTable.selectRowIndexes(indexSet, byExtendingSelection: false)
    }
}

extension NetworkViewController : NSTableViewDataSource
{
    //  NSTableViewDataSource
    func numberOfRows(in tableView: NSTableView) -> Int
    {
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return 0 }
        
        if (tableView == flowsTable) {
            //  Return the number of layers
            return doc.docData.flows.count
        }
        
        if (tableView == layersTable) {
            //  Return the number of layers
            if (currentFlow < 0 || currentFlow >= doc.docData.flows.count) { return 0 }
            return doc.docData.flows[currentFlow].layers.count
        }
        
        return 0
    }
    
}

extension NetworkViewController : NSTableViewDelegate
{
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView?
    {
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return nil }
        
        if (tableView == flowsTable) {
            if tableColumn == tableView.tableColumns[0] {
                if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Number"), owner: nil) as? NSTableCellView {
                    cell.textField?.integerValue = row
                    return cell
                }
            }
            else if tableColumn == tableView.tableColumns[1] {
                if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Input"), owner: nil) as? NSTableCellView {
                    cell.textField?.stringValue = doc.docData.flows[row].inputSourceString()
                    return cell
                }
            }
            else if tableColumn == tableView.tableColumns[2] {
                if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Input Size"), owner: nil) as? NSTableCellView {
                    let dimensions = doc.docData.getFlowInputDimensions(flowIndex : row)
                    cell.textField?.stringValue = NetworkViewController.dimensionsToString(dimensions: dimensions)
                    return cell
                }
            }
            else if tableColumn == tableView.tableColumns[3] {
                if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Output Size"), owner: nil) as? NSTableCellView {
                    let dimensions = doc.docData.getFlowOutputDimensions(flowIndex: row)
                    cell.textField?.stringValue = NetworkViewController.dimensionsToString(dimensions: dimensions)
                    return cell
                }
            }
            else if tableColumn == tableView.tableColumns[4] {
                if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Final"), owner: nil) as? NSTableCellView {
                    if (row == doc.docData.outputFlow) {
                        cell.textField?.stringValue = "Yes"
                    }
                    else {
                        cell.textField?.stringValue = "   "
                    }
                    return cell
                }
            }
            return nil
        }

        if (tableView == layersTable) {
            if (currentFlow < 0 || currentFlow >= doc.docData.flows.count) { return nil }
            if tableColumn == tableView.tableColumns[0] {
                if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Type"), owner: nil) as? NSTableCellView {
                    let typeString = doc.getTypeStringForFlowAndLayer(flowIndex: currentFlow, layerIndex: row)
                    cell.textField?.stringValue = typeString
                    return cell
                }
            }
            else if tableColumn == tableView.tableColumns[1] {
                if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Input"), owner: nil) as? NSTableCellView {
                    let inputDimensions = doc.getInputDimensionForFlowAndLayer(flowIndex: currentFlow, layerIndex: row)
                    cell.textField?.stringValue = NetworkViewController.dimensionsToString(dimensions: inputDimensions)
                    return cell
                }
            }
            else if tableColumn == tableView.tableColumns[2] {
                if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Parameters"), owner: nil) as? NSTableCellView {
                    cell.textField?.stringValue = doc.getParameterStringForFlowAndLayer(flowIndex: currentFlow, layerIndex: row)
                    return cell
                }
            }
            else if tableColumn == tableView.tableColumns[3] {
                if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Output"), owner: nil) as? NSTableCellView {
                    let outputDimensions = doc.getOutputDimensionForFlowAndLayer(flowIndex: currentFlow, layerIndex: row)
                    cell.textField?.stringValue = NetworkViewController.dimensionsToString(dimensions: outputDimensions)
                    return cell
                }
            }
        }
        
        return nil
    }
    
    func tableViewSelectionDidChange(_ notification: Notification)
    {
        //  Get the document
        guard let doc = view.window?.windowController?.document as? Document else { return }
        
        let table = notification.object as! NSTableView
        
        if (table == flowsTable) {
            let selection = flowsTable.selectedRow
            currentFlow = selection
            
            //  If a valid selection, enable the add layer button and possibly the duplicate flow button
            if (selection >= 0) {
                addLayerButton.isEnabled = true
                if (doc.docData.flows.count > 1) {
                    duplicateFlowButton.isEnabled = true
                }
                else {
                    duplicateFlowButton.isEnabled = false
                }
            }
            else {
                addLayerButton.isEnabled = false
                duplicateFlowButton.isEnabled = false
           }
            
            //  Update the layer table
            layersTable.reloadData()
            doc.resetLayerSelection()
        }
        
        
        if (table == layersTable) {
            if (currentFlow < 0 || currentFlow >= doc.docData.flows.count) { return }
            
            //  Remove the selection flag from all the layers
            doc.resetLayerSelection()
            
            //  Get the number of selections
            let numSelections = layersTable.numberOfSelectedRows
            
            //  If one selected, enable the insert, update, and delete buttons
            insertLayerButton.isEnabled = (numSelections == 1)
            updateLayerButton.isEnabled = (numSelections == 1)
            deleteLayerButton.isEnabled = (numSelections == 1)
            
            //  Get the selection and make the current layer
            if (numSelections == 1) {
                let row = layersTable.selectedRow
                if (row >= 0 && row < doc.docData.flows[currentFlow].layers.count) {
                    currentLayer.setFrom(layer: doc.docData.flows[currentFlow].layers[row])
                    doc.docData.flows[currentFlow].layers[row].selected = true
                    
                    //  Set the controls to the layer values
                    setControls()
                }
            }
        }
        
        //  Update the 3D view
        network3DScene.setFromDocument(document: doc.docData)
            
    }
}
