//
//  DuplicateFlowViewController.swift
//  SwiftNNTrainer
//
//  Created by Kevin Coble on 3/8/19.
//  Copyright © 2019 Kevin Coble. All rights reserved.
//

import Cocoa

class DuplicateFlowViewController: NSViewController {
    
    var docData : DocumentData?
    var fromFlowIndex : Int?
    
    @IBOutlet weak var fromFlow: NSTextField!
    @IBOutlet weak var toFlow: NSPopUpButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    override func viewDidAppear()
    {
        //  Set the controls to the data specifications
        fromFlow.integerValue = fromFlowIndex!
        let numFlows = docData!.flows.count
        toFlow.removeAllItems()
        for index in 0..<numFlows {
            if (index != fromFlowIndex!) {
                toFlow.addItem(withTitle: "\(index)")
            }
        }
    }

    @IBAction func onDuplicate(_ sender: Any) {
        //  Get the selected destination flow
        if let destination = Int(toFlow.selectedItem!.title) {
            
            //  If the flow already has layers, verify the duplication with the user
            if (docData!.flows[destination].layers.count > 0) {
                let alert = NSAlert()
                alert.addButton(withTitle: "Continue")
                alert.addButton(withTitle: "Cancel")
                alert.messageText = "Destination Flow has defined layers"
                alert.informativeText = "Any current layers will be deleted and replaced with copies from the source flow"
                alert.alertStyle = .warning
                alert.beginSheetModal(for: self.view.window!) { returnCode in
                    if (returnCode == .alertFirstButtonReturn) {
                        //  Duplicate the flow
                        self.docData!.duplicateFlow(self.fromFlowIndex!, toFlow: destination)
                        
                        //  Remove the sheet
                        self.view.window!.sheetParent!.endSheet(self.view.window!, returnCode: .OK)
                    }
                }
            }
            
            else {
                //  Duplicate the flow
                docData!.duplicateFlow(fromFlowIndex!, toFlow: destination)

                //  Remove the sheet
                view.window!.sheetParent!.endSheet(view.window!, returnCode: .OK)
            }
        }
    }
    
    @IBAction func onCancel(_ sender: Any) {
        //  Remove the sheet
        view.window!.sheetParent!.endSheet(view.window!, returnCode: .cancel)
    }
}
