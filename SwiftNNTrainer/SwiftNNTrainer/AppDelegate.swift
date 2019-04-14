//
//  AppDelegate.swift
//  SwiftNNTrainer
//
//  Created by Kevin Coble on 2/6/19.
//  Copyright © 2019 Kevin Coble. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {



    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    @IBAction func onImportMLModel(_ sender: Any) {
        //  Get the MLModel file
        let openPanel = NSOpenPanel()
        openPanel.allowedFileTypes = ["mlmodel"]
        openPanel.level = .modalPanel
        openPanel.begin { (result) in
            if result.rawValue == NSApplication.ModalResponse.OK.rawValue {
                do {
                    //  Get the model
                    let data = try Data(contentsOf: openPanel.url!)
                    let model = try CoreML_Specification_Model(serializedData: data)
                    
                    //  Create the document
                    let document = try Document(model: model)
                    document.makeWindowControllers()
                    document.showWindows() 
                    
                    //  Get the document controller and add the document
                    NSDocumentController.shared.addDocument(document)
                }
                catch {
                    let alert = NSAlert()
                    alert.addButton(withTitle: "OK")
                    alert.messageText = "Unable to read mlmodel file"
                    alert.informativeText = "The mlmodel file could not be read, or could not be formed into an mlmodel class"
                    alert.alertStyle = .critical
                    alert.runModal()
                    return
                }
            }
        }
    }
    
    @IBAction func onExportWithArrayInput(_ sender: Any) {
        export(asImage: false)
    }
    
    @IBAction func onExportWithImageInput(_ sender: Any) {
        export(asImage: true)
    }
    
    func export(asImage : Bool) {
        if let document = NSDocumentController.shared.currentDocument as? Document {
            //  Get the MLModel file
            let savePanel = NSSavePanel()
            savePanel.allowedFileTypes = ["mlmodel"]
            savePanel.level = .modalPanel
            savePanel.begin { (result) in
                do {
                    try document.exportMLModel(url: savePanel.url!, imageInput: asImage)
                }
                catch {
                    let alert = NSAlert()
                    alert.addButton(withTitle: "OK")
                    alert.messageText = "Unable to export mlmodel file"
                    alert.informativeText = "The mlmodel file could not be created, or could not be saved to the file specified"
                    alert.alertStyle = .critical
                    alert.runModal()
                    return
                }
            }
        }
    }
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool
    {
        if (menuItem.tag == 800) { return true }    //  Can always import
        if let document = NSDocumentController.shared.currentDocument as? Document {
            if (menuItem.tag == 900) { return true }    //  Can export any document with array inputs
            
            //  See if the input is sized appropriately for an image
            let inputDimensions = document.docData.inputDimensions
            if (inputDimensions[3] != 1) { return false }
            if (inputDimensions[2] != 1 && inputDimensions[2] != 3) { return false }
            if (inputDimensions[0] < 10 || inputDimensions[1] < 10) { return false }
            return true
        }
        return false
    }
}

