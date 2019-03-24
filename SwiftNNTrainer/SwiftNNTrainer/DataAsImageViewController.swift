//
//  DataAsImageViewController.swift
//  SwiftNNTrainer
//
//  Created by Kevin Coble on 2/18/19.
//  Copyright © 2019 Kevin Coble. All rights reserved.
//

import Cocoa

enum ShowData {
    case Input
    case Output
    case Result
}

class DataAsImageViewController: NSViewController {
    
    @IBOutlet weak var currentIndex: NSTextField!
    @IBOutlet weak var currentChannel: NSTextField!
    @IBOutlet weak var currentTime: NSTextField!
    @IBOutlet weak var dataTable: NSTableView!
    @IBOutlet weak var imageView: NSImageView!
    @IBOutlet weak var labelField: NSTextField!
    @IBOutlet weak var resultDataButton: NSButton!
    @IBOutlet weak var resultLabelLabel: NSTextField!
    @IBOutlet weak var resultLabelField: NSTextField!
    
    var data : [(input:[Float], output:[Float], outputClass: Int)]?
    var results : [(output:[Float], outputClass: Int)?]?
    var dataInputDimensions : [Int]?
    var dataOutputDimensions : [Int]?
    var displayedIndex = 0
    var minIndex = 1
    var maxIndex = 0
    var showData = ShowData.Input
    var displayChannel = 1
    var displayTime = 1
    var regression = false

    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    override func viewDidAppear()
    {
        showData = .Input
        
        //  If output dimensions are all feature channels, convert to Y column for better display
        if (dataOutputDimensions != nil) {
            if (dataOutputDimensions![0] == 1 && dataOutputDimensions![1] == 1 && dataOutputDimensions![3] == 1) {
                dataOutputDimensions![1] = dataOutputDimensions![2]
                dataOutputDimensions![2] = 1
            }
        }
        
        //  Set the dimensions on the table
        setTableDimensions()

        //  Set the data limits
        if let data = data {
            var sampleCount = data.count
            if let results = results {
                sampleCount = results.count
            }
            if (sampleCount > 0) {
                minIndex = 1
                maxIndex = sampleCount
                displayedIndex = 1
                currentIndex.integerValue = displayedIndex
                displayData()
            }
        }
        else {
            displayedIndex = 0
            minIndex = 1
            maxIndex = 0
            imageView.image = nil
        }
        
        //  If no result data, disable the fields
        if (results == nil) {
           resultDataButton.isEnabled = false
           resultLabelLabel.isEnabled = false
           resultLabelField.isEnabled = false
        }
        else {
            resultDataButton.isEnabled = true
            resultLabelLabel.isEnabled = true
            resultLabelField.isEnabled = true
        }
        
        if (regression) {
            labelField.stringValue = ""
            labelField.isEnabled = false
            
        }
    }

    @IBAction func onDataSourceChanged(_ sender: NSButton) {
        //  Set the type
        showData = .Input
        if (sender.tag == 1) { showData = .Output }
        if (sender.tag == 2) { showData = .Result }

        //  Start at channel and time 1
        displayChannel = 1
        displayTime = 1
        currentChannel.integerValue = displayChannel
        currentTime.integerValue = displayTime
        
        //  Set the channel maximum
        var limit = dataInputDimensions![2]
        if (showData != .Input) { limit = dataOutputDimensions![2] }
        (currentChannel.formatter! as! NumberFormatter).maximum = NSNumber(value: limit)
        
        //  Set the time maximum
        limit = dataInputDimensions![3]
        if (showData != .Input) { limit = dataOutputDimensions![3] }
        (currentTime.formatter! as! NumberFormatter).maximum = NSNumber(value: limit)

        //  Disable labels if regression
        if (regression) {
            labelField.stringValue = ""
            labelField.isEnabled = false
            resultLabelField.stringValue = ""
            resultLabelField.isEnabled = false
        }
        else {
            labelField.isEnabled = true
            resultLabelField.isEnabled = true
        }
        
        //  Set the dimensions on the table
        setTableDimensions()
        
        //  Display the current data
        displayData()
    }
    
    func setTableDimensions()
    {
        //  Get the number of columns needed
        var xSize = dataInputDimensions![0]
        if (showData != .Input) { xSize = dataOutputDimensions![0] }
        
        //  Get the number of columns in the table
        let currentColumns = dataTable.numberOfColumns
        
        //  If extra columns, remove some
        if (currentColumns > xSize) {
            for index in stride(from: currentColumns, to: xSize, by: -1) {
                let column = dataTable.tableColumns[index-1]
                dataTable.removeTableColumn(column)
             }
        }
        
        //  If needed, add more columns
        else if (currentColumns < xSize) {
            for index in (currentColumns+1)...xSize {
                let newColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("\(index)"))
                newColumn.headerCell.title = "\(index)"
                newColumn.headerCell.alignment = .center
                dataTable.addTableColumn(newColumn)
            }
        }
    }
    
    @IBAction func onPrevious(_ sender: Any) {
        if (displayedIndex > minIndex) {
            displayedIndex -= 1
            currentIndex.integerValue = displayedIndex
            displayData()
        }
    }
    
    @IBAction func onNext(_ sender: Any) {
        if (displayedIndex < maxIndex) {
            displayedIndex += 1
            currentIndex.integerValue = displayedIndex
            displayData()
        }
    }
    
    @IBAction func onIndexChanged(_ sender: NSTextField) {
        displayedIndex = sender.integerValue
        if (displayedIndex < minIndex) { displayedIndex = minIndex }
        if (displayedIndex > maxIndex) { displayedIndex = maxIndex }
        displayData()
    }
    
    @IBAction func onPreviousChannel(_ sender: Any)
    {
        if (displayChannel > 1) {
            displayChannel -= 1
            currentChannel.integerValue = displayChannel
            displayData()
        }
    }
    
    @IBAction func onNextChannel(_ sender: Any)
    {
        var limit = dataInputDimensions![2]
        if (showData != .Input) { limit = dataOutputDimensions![2] }
        
        if (displayChannel < limit) {
            displayChannel += 1
            currentChannel.integerValue = displayChannel
            displayData()
        }
    }
    
    @IBAction func onChannelChanged(_ sender: NSTextField)
    {
        var limit = dataInputDimensions![2]
        if (showData != .Input) { limit = dataOutputDimensions![2] }
        
        displayChannel = sender.integerValue
        if (displayChannel < 1) { displayChannel = 1 }
        if (displayChannel > limit) { displayChannel = limit }
        displayData()
    }
    
    @IBAction func onPreviousTime(_ sender: Any)
    {
        if (displayTime > 1) {
            displayTime -= 1
            currentTime.integerValue = displayTime
            displayData()
        }
    }
    
    @IBAction func onNextTime(_ sender: Any)
    {
        var limit = dataInputDimensions![3]
        if (showData != .Input) { limit = dataOutputDimensions![3] }
        
        if (displayTime < limit) {
            displayTime += 1
            currentTime.integerValue = displayTime
            displayData()
        }
    }
    
    @IBAction func onTimeChanged(_ sender: NSTextField)
    {
        var limit = dataInputDimensions![3]
        if (showData != .Input) { limit = dataOutputDimensions![3] }
        
        displayTime = sender.integerValue
        if (displayTime < 1) { displayTime = 1 }
        if (displayTime > limit) { displayTime = limit }
        displayData()
    }
    
    @IBAction func onDone(_ sender: Any) {
        //  Remove the sheet
        view.window!.sheetParent!.endSheet(view.window!, returnCode: .OK)
    }
    
    func displayData()
    {
        if (displayedIndex < minIndex || displayedIndex > maxIndex) { return }
        if let data = data {
            if (showData == .Input) {
                if let image = getImageFromData(data[displayedIndex-1].input, dimensions: dataInputDimensions!) {
                    imageView.image = image
                    if (!regression) {
                        labelField.integerValue = data[displayedIndex-1].outputClass
                        if let results = results {
                            if let result = results[displayedIndex-1] {
                                resultLabelField.integerValue = result.outputClass
                            }
                        }
                    }
                }
            }
            else if (showData == .Output) {
                if let image = getImageFromData(data[displayedIndex-1].output, dimensions: dataOutputDimensions!) {
                    imageView.image = image
                    if (!regression) {
                        labelField.integerValue = data[displayedIndex-1].outputClass
                        if let results = results {
                            if let result = results[displayedIndex-1] {
                                resultLabelField.integerValue = result.outputClass
                            }
                        }
                    }
                }
            }
            else {
                if let results = results {
                    if let result = results[displayedIndex-1] {
                        if let image = getImageFromData(result.output, dimensions: dataOutputDimensions!) {
                            imageView.image = image
                            if (!regression) {
                                labelField.integerValue = data[displayedIndex-1].outputClass
                                resultLabelField.integerValue = result.outputClass
                            }
                        }
                    }
                    else {
                        imageView.image = nil
                        labelField.stringValue = ""
                        resultLabelField.stringValue = ""
                    }
                }
                else {
                    imageView.image = nil
                    labelField.stringValue = ""
                    resultLabelField.stringValue = ""
                }
            }
         }
        
        //  Update the table
        dataTable.reloadData()
    }
    
    func getImageFromData(_ sourceData: [Float], dimensions: [Int]) ->NSImage?
    {
        //  Get the number of channels to be set
        var samples = 1
        var colorSpace = NSColorSpaceName.calibratedWhite
        var hasAlpha = false
        if (dimensions[2] > 1) {
            samples = 4
            colorSpace = NSColorSpaceName.calibratedRGB
            hasAlpha = true
        }
        
        //  Get the channel/time offset
        var channelTimeOffset : Int
        channelTimeOffset = (displayTime - 1) * dimensions[0] * dimensions[1] * dimensions[2]
        if (samples == 1) { channelTimeOffset += (displayChannel - 1) * dimensions[0] * dimensions[1] }
        
        //  Get a bitmap representation
        if let representation = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: dimensions[0], pixelsHigh: dimensions[1], bitsPerSample: 8, samplesPerPixel: samples, hasAlpha: hasAlpha, isPlanar: false, colorSpaceName: colorSpace, bytesPerRow: 0, bitsPerPixel: samples * 8) {
            let rowBytes = representation.bytesPerRow
            let pixels = representation.bitmapData
            var posIndex = channelTimeOffset
            let channelOffset = dimensions[0] * dimensions[1]
            for y in 0..<dimensions[1] {
                var byteIndex = y * rowBytes
                for _ in 0..<dimensions[0] {
                    var index = posIndex
                    for channel in 0..<samples {
                        if (channel < dimensions[2]) {
                            let value = sourceData[index] * 255.0
                            if (value > Float(UInt8.max)) {
                                pixels?[byteIndex] = UInt8.max
                            }
                            else if (value < Float(UInt8.min)) {
                                pixels?[byteIndex] = UInt8.min
                            }
                            else if (value.isNaN) {
                                pixels?[byteIndex] = 0
                            }
                            else {
                                pixels?[byteIndex] = UInt8(value)
                            }
                            index += channelOffset
                        }
                        else {
                            pixels?[byteIndex] = UInt8(255)
                        }
                        byteIndex += 1
                    }
                    posIndex += 1
                }
            }
            
            let image = NSImage(size: NSSize(width: dimensions[0], height: dimensions[1]))
            image.addRepresentation(representation)
            
            //  Scale the image to the view
            let scaledImage = NSImage(size: imageView.bounds.size)
            scaledImage.lockFocus()
            image.draw(in: imageView.bounds, from: NSRect(origin: NSZeroPoint, size: image.size), operation: .copy, fraction: 1.0, respectFlipped: true, hints: [NSImageRep.HintKey.interpolation : NSImageInterpolation.none.rawValue])
            scaledImage.unlockFocus()
            return scaledImage
         }
        
        return nil
    }

}



extension DataAsImageViewController : NSTableViewDataSource
{
    //  NSTableViewDataSource
    func numberOfRows(in tableView: NSTableView) -> Int
    {
        if (showData == .Input) {
            if let dimensions = dataInputDimensions {
                return dimensions[1]
            }
        }
        else {
            if let dimensions = dataOutputDimensions {
                return dimensions[1]
            }
        }
        return 0
    }
}

extension DataAsImageViewController : NSTableViewDelegate
{
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView?
    {
        if (displayedIndex < minIndex) { return nil }
        var numColumns = -1
        //  Get the number of columns
        if (showData == .Input) {
            if let dimensions = dataInputDimensions {
                numColumns = dimensions[0]
            }
        }
        else {
            if let dimensions = dataOutputDimensions {
                numColumns = dimensions[0]
            }
        }
        if (numColumns <= 0) { return nil }
        
        for column in 0..<numColumns {
            if tableColumn == tableView.tableColumns[column] {
                if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "1"), owner: nil) as? NSTableCellView {
                    var value = Float.nan
                    if (showData == .Input) {
                        if let dimensions = dataInputDimensions {
                            let index = (((displayTime - 1) * dimensions[2] + (displayChannel - 1)) * dimensions[1] + row) * dimensions[0] + column
                            value = data![displayedIndex-1].input[index]
                        }
                    }
                    else {
                        if let dimensions = dataOutputDimensions {
                            let index = (((displayTime - 1) * dimensions[2] + (displayChannel - 1)) * dimensions[1] + row) * dimensions[0] + column
                            if (showData == .Output) {
                                value = data![displayedIndex-1].output[index]
                            }
                            else {
                                //  Verify we tested this sample
                                if let result = results![displayedIndex-1] {
                                    value = result.output[index]
                                }
                                else {
                                    value = 0.0
                                }
                            }
                        }
                    }
                    if (value == Float.nan) { return nil }
                    cell.textField?.stringValue = "\(value)"
                    return cell
                }
                break
            }
        }
        
        return nil
    }
}
