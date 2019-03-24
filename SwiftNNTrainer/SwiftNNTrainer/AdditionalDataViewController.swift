//
//  AdditionalDataViewController.swift
//  SwiftNNTrainer
//
//  Created by Kevin Coble on 2/25/19.
//  Copyright © 2019 Kevin Coble. All rights reserved.
//

import Cocoa

class AdditionalDataViewController: NSViewController {
    
    @IBOutlet weak var checkbox1: NSButton!
    @IBOutlet weak var label1: NSTextField!
    @IBOutlet weak var value1: NSTextField!
    @IBOutlet weak var checkbox2: NSButton!
    @IBOutlet weak var label2: NSTextField!
    @IBOutlet weak var value2: NSTextField!
    @IBOutlet weak var checkbox3: NSButton!
    @IBOutlet weak var label3: NSTextField!
    @IBOutlet weak var value3: NSTextField!
    @IBOutlet weak var checkbox4: NSButton!
    @IBOutlet weak var label4: NSTextField!
    @IBOutlet weak var value4: NSTextField!
    @IBOutlet weak var checkbox5: NSButton!
    @IBOutlet weak var label5: NSTextField!
    @IBOutlet weak var value5: NSTextField!
    @IBOutlet weak var checkbox6: NSButton!
    @IBOutlet weak var label6: NSTextField!
    @IBOutlet weak var value6: NSTextField!
    @IBOutlet weak var checkbox7: NSButton!
    @IBOutlet weak var label7: NSTextField!
    @IBOutlet weak var value7: NSTextField!
    @IBOutlet weak var checkbox8: NSButton!
    @IBOutlet weak var label8: NSTextField!
    @IBOutlet weak var value8: NSTextField!
    
    var infoDescription : [AdditionalDataInfo]?
    var currentValues : [Float]?
    
    var checkboxes : [NSButton]?
    var labels : [NSTextField]?
    var values : [NSTextField]?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        //  Make arrays of the fields
        checkboxes = [checkbox1, checkbox2, checkbox3, checkbox4, checkbox5, checkbox6, checkbox7, checkbox8]
        labels = [label1, label2, label3, label4, label5, label6, label7, label8]
        values = [value1, value2, value3, value4, value5, value6, value7, value8]
        
        //  Increase the size of the checkboxes and the labels
        for i in 0..<8 {
            var size = checkboxes![i].frame.size
            size.width = (values![i].frame.origin.x + values![i].frame.size.width) - checkboxes![i].frame.origin.x
            checkboxes![i].setFrameSize(size)
            
            size = labels![i].frame.size
            var origin = labels![i].frame.origin
            let increase = labels![i].frame.origin.x - checkboxes![i].frame.origin.x
            size.width += increase
            origin.x -= increase
            labels![i].setFrameOrigin(origin)
            labels![i].setFrameSize(size)
       }
        
        //  Set the controls
//        setControls()
    }
    
    override func viewDidAppear()
    {
        //  Set the controls to the data specifications
        setControls()
    }
    
    func setControls()
    {
        if (infoDescription == nil) { return }
        for i in 0..<8 {
            if (i < infoDescription!.count) {
                //  Have an entry, set based on type
                if (infoDescription![i].type == .bool) {
                    //  Hide the label and value
                    checkboxes![i].isHidden = false
                    labels![i].isHidden = true
                    values![i].isHidden = true
                    
                    //  Set the checkbox title
                    checkboxes![i].title = infoDescription![i].name
                    
                    //  Set the checkmark value
                    checkboxes![i].state = (currentValues![i]) > 0.5 ? .on : .off

                }
                else {
                    //  Hide the checkbox
                    checkboxes![i].isHidden = true
                    labels![i].isHidden = false
                    values![i].isHidden = false
                    
                    //  Set the label
                    labels![i].stringValue = infoDescription![i].name
                    
                    //  Set the value
                    values![i].floatValue = currentValues![i]
               }
            }
            else {
                //  No entry - hide all the controls
                checkboxes![i].isHidden = true
                labels![i].isHidden = true
                values![i].isHidden = true
            }
        }
    }
    
    @IBAction func onValueChanged(_ sender: NSTextField) {
        //  If an integer, update the value
        let tag = sender.tag
        if (tag < 0 || tag >= infoDescription!.count) { return }
        
        //  Integerize if needed
        if (infoDescription![tag].type == .int) {
            var intValue = Int(sender.floatValue)
            if (intValue < Int(infoDescription![tag].minimum)) { intValue = Int(infoDescription![tag].minimum) }
            if (intValue > Int(infoDescription![tag].maximum)) { intValue = Int(infoDescription![tag].maximum) }
            sender.integerValue = intValue      //  Put it back in case we integerized a float entry
            return
        }
        
        //  Limit chec
        let floatValue = sender.floatValue
        if (floatValue < infoDescription![tag].minimum) {
            sender.floatValue = infoDescription![tag].minimum
        }
        if (floatValue > infoDescription![tag].maximum) {
            sender.floatValue = infoDescription![tag].maximum
        }
    }
    
    @IBAction func onDone(_ sender: Any) {
        //  Get the values
        for i in 0..<8 {
            if (i < infoDescription!.count) {
                if (infoDescription![i].type == .bool) {
                    currentValues![i] = (checkboxes![i].state == .on) ? 1.0 : 0.0
                }
                else {
                    currentValues![i] = values![i].floatValue
                }
            }
        }
        
        //  Remove the sheet
        view.window!.sheetParent!.endSheet(view.window!, returnCode: .OK)
    }
    
    @IBAction func onCancel(_ sender: Any) {
        //  Remove the sheet
        view.window!.sheetParent!.endSheet(view.window!, returnCode: .cancel)
    }
}
