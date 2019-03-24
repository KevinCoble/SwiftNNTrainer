//
//  UpdateRuleViewController.swift
//  SwiftNNTrainer
//
//  Created by Kevin Coble on 3/18/19.
//  Copyright © 2019 Kevin Coble. All rights reserved.
//

import Cocoa
import Metal
import MetalPerformanceShaders

class UpdateRuleViewController: NSViewController {

    @IBOutlet weak var updateRule: NSPopUpButton!
    @IBOutlet weak var learningRateMultiplier: NSTextField!
    @IBOutlet weak var momentumScaleLabel: NSTextField!
    @IBOutlet weak var momentumScale: NSTextField!
    @IBOutlet weak var useNesterovMomentum: NSButton!
    @IBOutlet weak var beta1Label: NSTextField!
    @IBOutlet weak var beta1: NSTextField!
    @IBOutlet weak var beta2Label: NSTextField!
    @IBOutlet weak var beta2: NSTextField!
    @IBOutlet weak var timeStepLabel: NSTextField!
    @IBOutlet weak var timeStep: NSTextField!
    @IBOutlet weak var timeStepStepper: NSStepper!
    @IBOutlet weak var epsilonLabel: NSTextField!
    @IBOutlet weak var epsilon: NSTextField!
    @IBOutlet weak var gradientRescale: NSTextField!
    @IBOutlet weak var clipGradients: NSButton!
    @IBOutlet weak var gradientClipMinimum: NSTextField!
    @IBOutlet weak var gradientClipMaximum: NSTextField!
    @IBOutlet weak var regularizationType: NSPopUpButton!
    @IBOutlet weak var regularizationScale: NSTextField!
    
    var currentUpdateRule : UpdateRule = .SGD
    var currentLearningRateMultiplier : Float = 1.0
    var currentMomentumScale : Float = 0.0
    var currentUseNesterovMomentum = false
    var currentEpsilon : Float = 1e-08
    var currentBeta1 : Double = 0.9      //  Used as decay for RMSProp
    var currentBeta2 : Double = 0.999
    var currentTimeStep = 0
    var currentGradientRescale : Float = 1.0
    var currentApplyGradientClipping = false
    var currentGradientClipMax : Float = -1.0
    var currentGradientClipMin : Float = 1.0
    var currentRegularizationType : MPSNNRegularizationType = .None
    var currentRegularizationScale : Float = 1.0

    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        viewDidAppear()
    }
    
    override func viewDidAppear() {
        //  Set the control values
        switch (currentUpdateRule) {
        case .SGD:
            updateRule.selectItem(withTag: 1)
        case .RMSProp:
            updateRule.selectItem(withTag: 2)
        case .Adam:
            updateRule.selectItem(withTag: 3)
        }
        learningRateMultiplier.floatValue = currentLearningRateMultiplier
        momentumScale.floatValue = currentMomentumScale
        useNesterovMomentum.state = currentUseNesterovMomentum ? .on : .off
        beta1.doubleValue = currentBeta1
        beta2.doubleValue = currentBeta2
        timeStep.integerValue = currentTimeStep
        timeStepStepper.integerValue = currentTimeStep
        epsilon.floatValue = currentEpsilon
        gradientRescale.floatValue = currentGradientRescale
        clipGradients.state = currentApplyGradientClipping ? .on : .off
        gradientClipMinimum.floatValue = currentGradientClipMin
        gradientClipMaximum.floatValue = currentGradientClipMax
        switch (currentRegularizationType) {
        case .None:
            regularizationType.selectItem(withTag: 1)
        case .L1:
            regularizationType.selectItem(withTag: 2)
        case .L2:
            regularizationType.selectItem(withTag: 3)
        }
        regularizationScale.floatValue = currentRegularizationScale

        //  Enable/disable controls as needed
        setControls()
    }
    
    func setControls()
    {
        //  Hide controls based on the update rule
        switch (currentUpdateRule) {
        case .SGD:
            momentumScaleLabel.isHidden = false
            momentumScale.isHidden = false
            useNesterovMomentum.isHidden = false
            beta1Label.isHidden = true
            beta1.isHidden = true
            beta2Label.isHidden = true
            beta2.isHidden = true
            timeStepLabel.isHidden = true
            timeStep.isHidden = true
            timeStepStepper.isHidden = true
            epsilonLabel.isHidden = true
            epsilon.isHidden = true
            useNesterovMomentum.isEnabled = (currentMomentumScale > 0.0)
        case .RMSProp:
            momentumScaleLabel.isHidden = true
            momentumScale.isHidden = true
            useNesterovMomentum.isHidden = true
            beta1Label.isHidden = false
            beta1.isHidden = false
            beta2Label.isHidden = true
            beta2.isHidden = true
            timeStepLabel.isHidden = true
            timeStep.isHidden = true
            timeStepStepper.isHidden = true
            epsilonLabel.isHidden = false
            epsilon.isHidden = false
            beta1Label.stringValue = "Decay:"
        case .Adam:
            momentumScaleLabel.isHidden = true
            momentumScale.isHidden = true
            useNesterovMomentum.isHidden = true
            beta1Label.isHidden = false
            beta1.isHidden = false
            beta2Label.isHidden = false
            beta2.isHidden = false
            timeStepLabel.isHidden = false
            timeStep.isHidden = false
            timeStepStepper.isHidden = false
            epsilonLabel.isHidden = false
            epsilon.isHidden = false
            beta1Label.stringValue = "Beta1:"
        }

        //  Enable clip limits
        gradientClipMinimum.isEnabled = currentApplyGradientClipping
        gradientClipMaximum.isEnabled = currentApplyGradientClipping

        //  Enable regularization scale
        regularizationScale.isEnabled = (currentRegularizationType != .None)
    }

    @IBAction func onUpdateRuleChanged(_ sender: Any) {
        //  Get the value
        if (updateRule.selectedTag() == 1) { currentUpdateRule = .SGD}
        if (updateRule.selectedTag() == 2) { currentUpdateRule = .RMSProp}
        if (updateRule.selectedTag() == 3) { currentUpdateRule = .Adam}

        //  Update the controls
        setControls()
    }
    
    @IBAction func onMomentumScaleChanged(_ sender: Any) {
        //  Get the value
        currentMomentumScale = momentumScale.floatValue
        
        //  Enable Nesterov momentum selection if momentum being used
        useNesterovMomentum.isEnabled = (currentMomentumScale > 0.0)
    }
    
    @IBAction func onTimeStepFieldChanged(_ sender: Any) {
        //  Set the stepper from the text field
        if (timeStepStepper.intValue == timeStep.integerValue) {return}       //  Stop loops
        timeStepStepper.integerValue = timeStep.integerValue
    }
    
    @IBAction func onTimeStepStepperChanged(_ sender: Any) {
        //  Set the text field from the stepper
        if (timeStep.integerValue == timeStepStepper.integerValue) {return}       //  Stop loops
        timeStep.integerValue = timeStepStepper.integerValue
    }
    
    @IBAction func onClipGradientsChanged(_ sender: Any) {
        //  Get the value
        currentApplyGradientClipping = (clipGradients.state == .on)

        //  Enable clip limits
        gradientClipMinimum.isEnabled = currentApplyGradientClipping
        gradientClipMaximum.isEnabled = currentApplyGradientClipping
    }
    
    @IBAction func onRegularizationTypeChanged(_ sender: Any) {
        //  Get the value
        if (regularizationType.selectedTag() == 1) { currentRegularizationType = .None}
        if (regularizationType.selectedTag() == 2) { currentRegularizationType = .L1}
        if (regularizationType.selectedTag() == 3) { currentRegularizationType = .L2}

        //  Enable regularization scale
        regularizationScale.isEnabled = (currentRegularizationType != .None)
    }
    
    @IBAction func onCancel(_ sender: Any) {
        //  Remove the sheet
        view.window!.sheetParent!.endSheet(view.window!, returnCode: .cancel)
    }
    
    @IBAction func onSet(_ sender: Any) {
        //  Get the learning rate multiplier
        currentLearningRateMultiplier = learningRateMultiplier.floatValue
        
        //  Get the values that matter for the selected update rule
        switch (currentUpdateRule) {
        case .SGD:
            currentMomentumScale = momentumScale.floatValue
            currentUseNesterovMomentum = (useNesterovMomentum.state == .on)
        case .RMSProp:
            currentBeta1 = beta1.doubleValue    //  Decay
            currentEpsilon = epsilon.floatValue
        case .Adam:
            currentBeta1 = beta1.doubleValue
            currentBeta2 = beta2.doubleValue
            currentTimeStep = timeStep.integerValue
            currentEpsilon = epsilon.floatValue
        }
        
        //  Get the gradient rescale
        currentGradientRescale = gradientRescale.floatValue
        
        //  Get the gradient clipping parameters
        if (currentApplyGradientClipping) {
            currentGradientClipMin = gradientClipMinimum.floatValue
            currentGradientClipMax = gradientClipMaximum.floatValue
        }
        
        //  Get the regularization scale
        if (currentRegularizationType != .None) {
            currentRegularizationScale = regularizationScale.floatValue
        }

        //  Remove the sheet
        self.view.window!.sheetParent!.endSheet(self.view.window!, returnCode: .OK)
    }
}
