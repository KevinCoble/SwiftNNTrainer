//
//  PaddingViewController.swift
//  SwiftNNTrainer
//
//  Created by Kevin Coble on 2/22/19.
//  Copyright © 2019 Kevin Coble. All rights reserved.
//

import Cocoa
import MetalPerformanceShaders
import MetalKit

class PaddingViewController: NSViewController {
    
    @IBOutlet weak var edgeModeButton: NSPopUpButton!
    @IBOutlet weak var constantValue: NSTextField!
    @IBOutlet weak var xMethod: NSPopUpButton!
    @IBOutlet weak var xOffset: NSTextField!
    @IBOutlet weak var xWidth: NSTextField!
    @IBOutlet weak var yMethod: NSPopUpButton!
    @IBOutlet weak var yOffset: NSTextField!
    @IBOutlet weak var yHeight: NSTextField!
    @IBOutlet weak var fMethod: NSPopUpButton!
    @IBOutlet weak var fOffset: NSTextField!
    @IBOutlet weak var fDepth: NSTextField!
    @IBOutlet weak var exampleXSize: NSTextField!
    @IBOutlet weak var exampleYSize: NSTextField!
    @IBOutlet weak var sourceView: PaddingExampleView!
    @IBOutlet weak var destinationView: PaddingExampleView!
    
    //  Editable variables
    var XPaddingMethod : PaddingMethod = .ValidOnly
    var YPaddingMethod : PaddingMethod = .ValidOnly
    var featurePaddingMethod : PaddingMethod = .ValidOnly
    var XOffset = 0
    var YOffset = 0
    var featureOffset = 0
    var clipWidth = 0
    var clipHeight = 0
    var clipDepth = 0
    var edgeMode : MPSImageEdgeMode = .zero
    var paddingConstant : Float = 1.0

    //  Needed for example
    var currentExampleXSize = 10
    var currentExampleYSize = 10
    var kernelX = 3
    var kernelY = 3
    var strideX = 1
    var strideY = 1
    var selectedX = 0
    var selectedY = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        
        sourceView.controller = self
        destinationView.controller = self
        
        //  If not available, remove some of the clamp options
        if #available(OSX 10.14.1, *) {
        } else {
            edgeModeButton.removeItem(at: 4)
            edgeModeButton.removeItem(at: 3)
            edgeModeButton.removeItem(at: 2)
        }
    }
    
    override func viewDidAppear()
    {
        switch (edgeMode) {
        case .zero:
            edgeModeButton.selectItem(withTag: 0)
        case .clamp:
            edgeModeButton.selectItem(withTag: 1)
        case .constant:
            if #available(OSX 10.14.1, *) {
                edgeModeButton.selectItem(withTag: 2)
            } else {
                edgeModeButton.selectItem(withTag: 0)
            }
        case .mirror:
            if #available(OSX 10.14.1, *) {
                edgeModeButton.selectItem(withTag: 3)
            } else {
                edgeModeButton.selectItem(withTag: 0)
            }
        case .mirrorWithEdge:
            if #available(OSX 10.14.1, *) {
                edgeModeButton.selectItem(withTag: 4)
            } else {
                edgeModeButton.selectItem(withTag: 0)
            }
        }
        if #available(OSX 10.14.1, *) {
            if (edgeMode == .constant) {
                constantValue.floatValue = paddingConstant
                constantValue.isEnabled = true
            }
            else {
                constantValue.stringValue = ""
                constantValue.isEnabled = false
            }
        } else {
            constantValue.stringValue = ""
            constantValue.isEnabled = false
        }
        
        
        xMethod.selectItem(withTag: XPaddingMethod.rawValue)
        xOffset.integerValue = XOffset
        xWidth.integerValue = clipWidth
        xOffset.isEnabled = (XPaddingMethod == .Custom)
        xWidth.isEnabled = (XPaddingMethod == .Custom)
        
        yMethod.selectItem(withTag: YPaddingMethod.rawValue)
        yOffset.integerValue = XOffset
        yHeight.integerValue = clipHeight
        yOffset.isEnabled = (YPaddingMethod == .Custom)
        yHeight.isEnabled = (YPaddingMethod == .Custom)
        
        fMethod.selectItem(withTag: featurePaddingMethod.rawValue)
        fOffset.integerValue = XOffset
        fDepth.integerValue = clipDepth
        fOffset.isEnabled = (featurePaddingMethod == .Custom)
        fDepth.isEnabled = (featurePaddingMethod == .Custom)
    }
    
    @IBAction func onEdgeModeChanged(_ sender: NSPopUpButton) {
        constantValue.stringValue = ""
        constantValue.isEnabled = false
        switch (edgeModeButton.selectedTag()) {
        case 0:
            edgeMode = .zero
        case 1:
            edgeMode = .clamp
        case 2:
            if #available(OSX 10.14.1, *) {
                edgeMode = .constant
                constantValue.floatValue = paddingConstant
                constantValue.isEnabled = true
            } else {
                edgeMode = .zero
            }
        case 3:
            if #available(OSX 10.14.1, *) {
                edgeMode = .mirror
            } else {
                edgeMode = .zero
            }
        default:
            if #available(OSX 10.14.1, *) {
                edgeMode = .mirrorWithEdge
            } else {
                edgeMode = .zero
            }
        }
        
        updateExampleViews()
   }
    
    @IBAction func onConstantValueChange(_ sender: NSTextField) {
        paddingConstant = constantValue.floatValue
    }
    
    @IBAction func onXMethodChanged(_ sender: NSPopUpButton) {
        if let method = PaddingMethod(rawValue: sender.selectedTag()) {
            XPaddingMethod = method
            
            updateExampleViews()
            
            //  Enable/disable offset/clip based on method
            xOffset.isEnabled = (method == .Custom)
            xWidth.isEnabled = (method == .Custom)
        }
    }
    
    @IBAction func onXOffsetChanged(_ sender: NSTextField) {
        XOffset = sender.integerValue
        
        updateExampleViews()
    }
    
    @IBAction func onXWidthChanged(_ sender: NSTextField) {
        clipWidth = sender.integerValue
        
        updateExampleViews()
    }
    
    @IBAction func onYMethodChanged(_ sender: NSPopUpButton) {
        if let method = PaddingMethod(rawValue: sender.selectedTag()) {
            YPaddingMethod = method
            
            updateExampleViews()
            
            //  Enable/disable offset/clip based on method
            yOffset.isEnabled = (method == .Custom)
            yHeight.isEnabled = (method == .Custom)
        }
    }
    
    @IBAction func onYOffsetChanged(_ sender: NSTextField) {
        YOffset = sender.integerValue
        
        updateExampleViews()
    }
    
    @IBAction func onYHeightChanged(_ sender: NSTextField) {
        clipHeight = sender.integerValue
        
        updateExampleViews()
    }
    
    @IBAction func onFMethodChanged(_ sender: NSPopUpButton) {
        if let method = PaddingMethod(rawValue: sender.selectedTag()) {
            featurePaddingMethod = method
            
            updateExampleViews()
            
            //  Enable/disable offset/clip based on method
            fOffset.isEnabled = (method == .Custom)
            fDepth.isEnabled = (method == .Custom)
        }
    }
    
    @IBAction func onFOffsetChanged(_ sender: NSTextField) {
        featureOffset = sender.integerValue
        
        updateExampleViews()
    }
    
    @IBAction func onFDepthChanged(_ sender: NSTextField) {
        clipDepth = sender.integerValue
        
        updateExampleViews()
    }
    
    @IBAction func onDecreaseXExampleSize(_ sender: Any) {
        if (currentExampleXSize > 1) {
            currentExampleXSize -= 1
            exampleXSize.integerValue = currentExampleXSize
            
            updateExampleViews()
        }
    }
    
    @IBAction func onExampleXSizeChanged(_ sender: NSTextField) {
        var value = exampleXSize.integerValue
        if (value < 1) {
            value = 1
            exampleXSize.integerValue = value
        }
        if (value > 1) {
            value = 100
            exampleXSize.integerValue = value
        }
        
        currentExampleXSize = value
        updateExampleViews()
    }
    
    @IBAction func onIncreaseXExampleSize(_ sender: Any) {
        if (currentExampleXSize < 100) {
            currentExampleXSize += 1
            exampleXSize.integerValue = currentExampleXSize
            
            updateExampleViews()
        }
    }
    
    @IBAction func onDecreaseYExampleSize(_ sender: Any) {
        if (currentExampleYSize > 1) {
            currentExampleYSize -= 1
            exampleYSize.integerValue = currentExampleYSize
            
            updateExampleViews()
        }
    }
    
    @IBAction func onExampleYSizeChanged(_ sender: NSTextField) {
        var value = exampleYSize.integerValue
        if (value < 1) {
            value = 1
            exampleYSize.integerValue = value
        }
        if (value > 1) {
            value = 100
            exampleYSize.integerValue = value
        }
        
        currentExampleYSize = value
        updateExampleViews()
    }
    
    @IBAction func onIncreaseYExampleSize(_ sender: Any) {
        if (currentExampleYSize < 100) {
            currentExampleYSize += 1
            exampleYSize.integerValue = currentExampleYSize
            
            updateExampleViews()
        }
    }

    @IBAction func onDone(_ sender: Any) {
        //  Remove the sheet
        view.window!.sheetParent!.endSheet(view.window!, returnCode: .OK)
    }
    
    @IBAction func onCancel(_ sender: Any) {
        //  Remove the sheet
        view.window!.sheetParent!.endSheet(view.window!, returnCode: .cancel)
    }
    
    func updateExampleViews()
    {
        sourceView.setNeedsDisplay(sourceView.bounds)
        destinationView.setNeedsDisplay(destinationView.bounds)
    }
}
