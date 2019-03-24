//
//  DataParserViewController.swift
//  SwiftNNTrainer
//
//  Created by Kevin Coble on 2/18/19.
//  Copyright © 2019 Kevin Coble. All rights reserved.
//

import Cocoa

class DataParserViewController: NSViewController {
    @IBOutlet weak var chunkType: NSPopUpButton!
    @IBOutlet weak var length: NSTextField!
    @IBOutlet weak var lengthStepper: NSStepper!
    @IBOutlet weak var insertButton: NSButton!
    @IBOutlet weak var insertAfterButton: NSButton!
    @IBOutlet weak var updateButton: NSButton!
    @IBOutlet weak var deleteButton: NSButton!
    @IBOutlet weak var chunkTable: NSTableView!
    @IBOutlet weak var dataRuler: InputDataRuler!
    @IBOutlet weak var formatType: NSPopUpButton!
    @IBOutlet weak var postReadType: NSPopUpButton!
    @IBOutlet weak var repeatButton: NSButton!
    @IBOutlet weak var repeatTextField: NSTextField!
    @IBOutlet weak var repeatStepper: NSStepper!
    @IBOutlet weak var repeatDimension: NSPopUpButton!
    @IBOutlet weak var warningLabel: NSTextField!
    @IBOutlet weak var commentTable: NSTableView!
    @IBOutlet weak var deleteCommentButton: NSButton!
    @IBOutlet weak var addCommentButton: NSButton!
    @IBOutlet weak var commentEntryField: NSTextField!
    @IBOutlet weak var skipLines: NSTextField!
    @IBOutlet weak var skipLinesStepper: NSStepper!
    
    var parser : DataParser?
    var textEntry = false

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    override func viewDidAppear()
    {
        //  Set the parser into the ruler
        dataRuler.dataParser = parser
        
        //  Update the table and ruler
        chunkTable.reloadData()
        dataRuler.setNeedsDisplay(dataRuler.bounds)
        commentTable.reloadData()
        
        //  Enable/disable controls based on binary/text entry
        deleteCommentButton.isEnabled = false  //  Require table selection
        addCommentButton.isEnabled = textEntry
        commentEntryField.isEnabled = textEntry
        skipLines.isEnabled = textEntry
        skipLinesStepper.isEnabled = textEntry
        
        //  Initialize the skip fields
        skipLines.integerValue = parser!.numSkipLines
        skipLinesStepper.integerValue = parser!.numSkipLines

        //  Validate
        validate()
    }

    @IBAction func onSetFormat(_ sender: Any) {
        //  Remove the sheet
        view.window!.sheetParent!.endSheet(view.window!, returnCode: .OK)
    }
    
    @IBAction func onCancel(_ sender: Any) {
        //  Remove the sheet
        view.window!.sheetParent!.endSheet(view.window!, returnCode: .cancel)
    }
    
    @IBAction func onChunkTypeChanged(_ sender: NSPopUpButton) {
        //  If the type is SetDimension, set the format pop-up to only have dimensions
        if (sender.selectedTag() == DataChunkType.SetDimension.rawValue) {
            formatType.removeAllItems()
            var formatValue = 101
            while (true) {
                if let format = DataFormatType(rawValue: formatValue) {
                    formatType.addItem(withTitle: format.typeString)
                    if let item = formatType.item(withTitle: format.typeString) {
                        item.tag = formatValue
                    }
                }
                else {
                    break
                }
                formatValue += 1
            }
            
            //  Set the minimum 'length' to 0
            (length.formatter! as! NumberFormatter).minimum = 0
            length.integerValue = 0
            lengthStepper.minValue = 0
            lengthStepper.integerValue = 0
        }
            
            //  Otherwise, just show data formats
        else {
            //  Skip if already there
            let selectedTag = formatType.selectedTag()
            if (selectedTag < DataFormatType.fTextString.rawValue && !textEntry) { return }
            if (selectedTag >= DataFormatType.fTextString.rawValue && selectedTag < 100 && textEntry) { return }
            formatType.removeAllItems()
            var formatValue = 1
            if (textEntry) { formatValue = DataFormatType.fTextString.rawValue }
            while (true) {
                if let format = DataFormatType(rawValue: formatValue) {
                    formatType.addItem(withTitle: format.typeString)
                    if let item = formatType.item(withTitle: format.typeString) {
                        item.tag = formatValue
                    }
                }
                else {
                    break
                }
                formatValue += 1
                if (!textEntry && formatValue == DataFormatType.fTextString.rawValue) { break }
            }
            
            //  Set the minimum 'length' to 1
            (length.formatter! as! NumberFormatter).minimum = 1
            lengthStepper.minValue = 1
            if (length.integerValue == 0) {
                length.integerValue = 1
                lengthStepper.integerValue = 1
            }
        }
    }
    
    @IBAction func onLengthChanged(_ sender: NSTextField) {
        //  Set the stepper from the text field
        if (lengthStepper.intValue == sender.integerValue) {return}       //  Stop loops
        lengthStepper.integerValue = Int(sender.integerValue)
    }
    @IBAction func onLengthStepperChanged(_ sender: NSStepper) {
        //  Set the text field from the stepper
        if (length.integerValue == sender.integerValue) {return}       //  Stop loops
        length.integerValue = Int(sender.integerValue)
    }
    
    @IBAction func addChunk(_ sender: Any) {
        //  Get the type
        if let type = DataChunkType(rawValue: chunkType.selectedTag()) {
            //  Get the format
            if let format = DataFormatType(rawValue: formatType.selectedTag()) {
                //  Get the post-read operation
                if let postRead = PostReadProcessing(rawValue: postReadType.selectedTag()) {
                    var post = postRead
                    if (type == .Repeat || type == .SetDimension) {post = .None}
                    
                    //  Create a new chunk
                    let chunk = DataChunk(type: type, length: length.integerValue, format : format, postProcessing : post)
                    
                    //  Add the chunk
                    parser!.chunks.append(chunk)
                    
                    //  Remove selections
                    chunkTable.deselectAll(self)
                    
                    //  Update the table and ruler
                    chunkTable.reloadData()
                    dataRuler.setNeedsDisplay(dataRuler.bounds)
                    
                    //  Validate
                    validate()
                }
            }
        }
    }
    
    @IBAction func insertChunk(_ sender: Any) {
        //  Get the selection
        let selectedRow = chunkTable.selectedRow
        if (selectedRow < 0) { return }
        
        //  Get the type
        if let type = DataChunkType(rawValue: chunkType.selectedTag()) {
            //  Get the format
            if let format = DataFormatType(rawValue: formatType.selectedTag()) {
                //  Get the post-read operation
                if let postRead = PostReadProcessing(rawValue: postReadType.selectedTag()) {
                    
                    //  Create a new chunk
                    let chunk = DataChunk(type: type, length: length.integerValue, format : format, postProcessing : postRead)
                    
                    //  Insert the chunk
                    parser!.insertChunk(chunk, atDisplayIndex: selectedRow)
                    
                    //  Remove selections
                    chunkTable.deselectAll(self)
                    
                    //  Update the table and ruler
                    chunkTable.reloadData()
                    dataRuler.setNeedsDisplay(dataRuler.bounds)
                    
                    //  Validate
                    validate()
                }
            }
        }
    }
    
    @IBAction func insertChunkAfter(_ sender: Any) {
        //  Get the selection
        let selectedRow = chunkTable.selectedRow
        if (selectedRow < 0) { return }
        
        //  Get the type
        if let type = DataChunkType(rawValue: chunkType.selectedTag()) {
            //  Get the format
            if let format = DataFormatType(rawValue: formatType.selectedTag()) {
                //  Get the post-read operation
                if let postRead = PostReadProcessing(rawValue: postReadType.selectedTag()) {
                    
                    //  Create a new chunk
                    let chunk = DataChunk(type: type, length: length.integerValue, format : format, postProcessing : postRead)
                    
                    //  Insert the chunk
                    parser!.insertChunkAfter(chunk, atDisplayIndex: selectedRow)
                    
                    //  Remove selections
                    chunkTable.deselectAll(self)
                    
                    //  Update the table and ruler
                    chunkTable.reloadData()
                    dataRuler.setNeedsDisplay(dataRuler.bounds)
                    
                    //  Validate
                    validate()
                }
            }
        }
    }
    
    @IBAction func updateChunk(_ sender: Any) {
        //  Get the selection
        let selectedRow = chunkTable.selectedRow
        if (selectedRow < 0) { return }
        
        //  Get the type
        if let type = DataChunkType(rawValue: chunkType.selectedTag()) {
            //  Get the format
            if let format = DataFormatType(rawValue: formatType.selectedTag()) {
                //  Get the post-read operation
                if let postRead = PostReadProcessing(rawValue: postReadType.selectedTag()) {
                    //  Create a new chunk
                    let chunk = DataChunk(type: type, length: length.integerValue, format : format, postProcessing : postRead)
                    
                    //  Replace the chunk
                    parser!.replaceChunk(chunk, atDisplayIndex: selectedRow)
                    
                    //  Remove selections
                    chunkTable.deselectAll(self)
                    
                    //  Update the table and ruler
                    chunkTable.reloadData()
                    dataRuler.setNeedsDisplay(dataRuler.bounds)
                    
                    //  Validate
                    validate()
                }
            }
        }
    }
    
    @IBAction func deleteChunk(_ sender: Any) {
        //  Get the selection range
        let selectedRows = chunkTable.selectedRowIndexes.sorted()
        
        //  Delete the rows
        parser!.deleteChunks(fromIndex: selectedRows[0], toIndex: selectedRows.last!)
        
        //  Remove selections
        chunkTable.deselectAll(self)
        
        //  Update the table and ruler
        chunkTable.reloadData()
        dataRuler.setNeedsDisplay(dataRuler.bounds)
        
        //  Validate
        validate()
    }
    
    @IBAction func onRepeatTextChanged(_ sender: NSTextField) {
        //  Set the stepper from the text field
        if (repeatStepper.intValue == sender.integerValue) {return}       //  Stop loops
        repeatStepper.integerValue = sender.integerValue
    }
    @IBAction func onRepeatStepperChanged(_ sender: NSStepper) {
        //  Set the text field from the stepper
        if (repeatTextField.integerValue == sender.integerValue) {return}       //  Stop loops
        repeatTextField.integerValue = sender.integerValue
    }
    
    @IBAction func onRepeat(_ sender: Any)
    {
        //  Get the selection range
        let selectedRows = chunkTable.selectedRowIndexes.sorted()
        
        //  Get the dimension
        let dimFormat = DataFormatType(rawValue: repeatDimension.selectedTag())
        if (dimFormat == nil) { return }
        
        //  Verify selected dimension is not already in repeat
        let repeatList = parser!.activeRepeats(atDisplayIndex: selectedRows[0])
        let dimensionIndex = dimFormat!.rawValue - DataFormatType.rDimension1.rawValue
        if (repeatList[dimensionIndex]) {
            let alert = NSAlert()
            alert.addButton(withTitle: "OK")
            alert.messageText = "The repeat dimension is already being repeated at the start of the selection"
            alert.informativeText = "Invalid repeat recursion"
            alert.alertStyle = .warning
            alert.beginSheetModal(for: view.window!) { returnCode in
            }
            return
        }
        
        //  Add the repeat
        parser!.repeatChunks(fromIndex: selectedRows[0], toIndex: selectedRows.last!, times: repeatTextField.integerValue, forDimension: dimFormat!)
        
        //  Remove selections
        chunkTable.deselectAll(self)

        //  Update the table and ruler
        chunkTable.reloadData()
        dataRuler.setNeedsDisplay(dataRuler.bounds)
        
        //  Validate
        validate()
    }
    
    @IBAction func onSkipLinesChanged(_ sender: NSTextField) {
        //  Set the stepper from the text field
        if (skipLinesStepper.intValue == sender.integerValue) {return}       //  Stop loops
        skipLinesStepper.integerValue = Int(sender.integerValue)
        parser!.numSkipLines = sender.integerValue
    }
    @IBAction func onSkipLinesStepperChanged(_ sender: NSStepper) {
        //  Set the text field from the stepper
        if (skipLines.integerValue == sender.integerValue) {return}       //  Stop loops
        skipLines.integerValue = Int(sender.integerValue)
        parser!.numSkipLines = sender.integerValue
    }
    
    @IBAction func deleteComment(_ sender: Any)
    {
        let selectedRow = commentTable.selectedRow
        if (selectedRow < 0 || selectedRow >= parser!.commentIndicators.count) { return }
        parser!.commentIndicators.remove(at: selectedRow)
        commentTable.deselectAll(self)
        commentTable.reloadData()
        deleteCommentButton.isEnabled = false   //  Selection was just deleted
    }
    
    @IBAction func addComment(_ sender: Any)
    {
        let string = commentEntryField.stringValue
        if (string.count > 0) {
            parser?.commentIndicators.append(string)
            commentTable.deselectAll(self)
            commentTable.reloadData()
        }
    }
    
    func validate()
    {
        var warning = ""
        
        //  Check for a sample repeat if not a text parse
        if (!textEntry) {
            if (!parser!.hasSampleRepeat()) {
                warning = "Warning:  No sample repeat"
            }
        }
        
        warningLabel.stringValue = warning
    }
}


extension DataParserViewController : NSTableViewDataSource
{
    //  NSTableViewDataSource
    func numberOfRows(in tableView: NSTableView) -> Int
    {
        //  Get the parser
        guard let parser = self.parser else { return 0 }
        
        if (tableView == chunkTable) {
            //  Return the number of chunks to display
            return parser.getNumDisplayChunks()
        }
        
        else if (tableView == commentTable) {
            //  Return the number of chunks to display
            return parser.commentIndicators.count
        }
        
        return 0
    }
    
}

extension DataParserViewController : NSTableViewDelegate
{
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView?
    {
        //  Get the parser
        guard let parser = self.parser else { return nil }
        
        if (tableView == chunkTable) {
            //  Get the chunk to be displayed
            if let result = parser.getChunkAtDisplayIndex(row) {
                
                if tableColumn == tableView.tableColumns[0] {
                    if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Type"), owner: nil) as? NSTableCellView {
                        var typeString = ""
                        for _ in 0..<result.repeatLevel { typeString += "   "}
                        typeString += result.chunk.type.typeString
                        cell.textField?.stringValue = typeString
                        return cell
                    }
                }
                else if tableColumn == tableView.tableColumns[1] {
                    if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Length"), owner: nil) as? NSTableCellView {
                        let length = result.chunk.length
                        cell.textField?.stringValue = "\(length)"
                        return cell
                    }
                }
                else if tableColumn == tableView.tableColumns[2] {
                    if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Format"), owner: nil) as? NSTableCellView {
                        let typeString = result.chunk.format.typeString
                        cell.textField?.stringValue = typeString
                        return cell
                    }
                }
                else if tableColumn == tableView.tableColumns[3] {
                    if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Post"), owner: nil) as? NSTableCellView {
                        let typeString = result.chunk.postProcessing.typeString
                        if (result.chunk.format.rawValue < 100) {
                            cell.textField?.stringValue = typeString
                        }
                        else {
                            cell.textField?.stringValue = ""
                       }
                        return cell
                    }
                }
            }
        }
        
        else if (tableView == commentTable) {
            if tableColumn == tableView.tableColumns[0] {
                if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Comment"), owner: nil) as? NSTableCellView {
                    cell.textField?.stringValue = parser.commentIndicators[row]
                    return cell
                }
            }
        }
        
        return nil
    }
    
    func tableViewSelectionDidChange(_ notification: Notification)
    {
        if ((notification.object as! NSTableView) == chunkTable) {
            //  Get the number of selections
            let numSelections = chunkTable.numberOfSelectedRows
            
            //  If one selected, enable the insert button
            insertButton.isEnabled = (numSelections == 1)
            insertAfterButton.isEnabled = (numSelections == 1)
            
            //  If one selected, and it is not a repeat, enable the update button
            var enableUpdate = false
            if (numSelections == 1) {
                let selectedRow = chunkTable.selectedRow
                if (selectedRow >= 0) {
                    if let chunk = parser!.getChunkAtDisplayIndex(selectedRow) {
                        if (chunk.chunk.type != .Repeat) {
                            enableUpdate = true
                            //  Fill the controls with the selected chunk's settings
                            chunkType.selectItem(withTag: chunk.chunk.type.rawValue)
                            length.integerValue = chunk.chunk.length
                            lengthStepper.integerValue = chunk.chunk.length
                            onChunkTypeChanged(chunkType)
                            formatType.selectItem(withTag: chunk.chunk.format.rawValue)
                            postReadType.selectItem(withTag: chunk.chunk.postProcessing.rawValue)
                        }
                    }
                }
            }
            updateButton.isEnabled = enableUpdate
            
            //  If any selection, see if we should enable the repeat and delete
            var enableRepeat = false
            if (numSelections > 0) {
                //  See if the selection is continueous
                var continuous = true
                let selectedRows = chunkTable.selectedRowIndexes.sorted()
                if (selectedRows.count > 1) {
                    var lastSelectedRow = selectedRows[0]
                    for selectedRowIndex in 1..<selectedRows.count {
                        if (selectedRows[selectedRowIndex] != lastSelectedRow + 1) {
                            continuous = false
                            break
                        }
                        lastSelectedRow = selectedRows[selectedRowIndex]
                    }
                }
                
                if (continuous) {
                    //  See of the sequence is in the same subchunk
                    enableRepeat = parser!.rangeCanRepeat(startIndex : selectedRows[0], endIndex : selectedRows.last!)
                }
            }
            
            repeatButton.isEnabled = enableRepeat
            repeatTextField.isEnabled = enableRepeat
            repeatStepper.isEnabled = enableRepeat
            repeatDimension.isEnabled = enableRepeat
            
            deleteButton.isEnabled = enableRepeat
        }
        
        else if ((notification.object as! NSTableView) == commentTable) {
            //  Get the number of selections
            let numSelections = commentTable.numberOfSelectedRows
            
            if (numSelections <= 0) {
                deleteCommentButton.isEnabled = false
            }
            else {
                deleteCommentButton.isEnabled = true
            }
        }
    }
}
