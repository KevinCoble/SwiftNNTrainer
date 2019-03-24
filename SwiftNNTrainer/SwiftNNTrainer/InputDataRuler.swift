//
//  InputDataRuler.swift
//  SwiftNNTrainer
//
//  Created by Kevin Coble on 2/13/19.
//  Copyright © 2019 Kevin Coble. All rights reserved.
//

import Cocoa

struct RepeatInfo {
    let startLoc : CGFloat
    let endLoc : CGFloat
    let repeatLevel : Int
    let dimension : Int
    let repeatLength : Int
}

class InputDataRuler: NSView {
    
    var dataParser : DataParser?
    var xStart : CGFloat = 0.0
    var totalLength = 0
    var repeatList : [RepeatInfo] = []
    var maxRepeatLevel = 0

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        //  Erase the background
        NSColor.textBackgroundColor.set()
        bounds.fill()
        
        //  We are done if we don't have a parser
        if let parser = dataParser {
            //  Get the length of a data item
            totalLength = parser.getDisplayLengthOfDataSample()
            if (totalLength == 0) { return }     //  No data
            
            //  Draw the chunks recursively
            xStart = 0.0
            repeatList = []
            maxRepeatLevel = 0
            drawChunksIn(parser.chunks, repeatLevel: 0)
            
            //  Label the repeats, if any
            if (repeatList.count > 0) {
                //  Get a font for the labels
                let fontSize = Double(maxRepeatLevel) * Double(bounds.size.height) * 0.2 * 0.9
                let labelColor = NSColor.blue
                let attributes = [NSFontDescriptor.AttributeName.name : "Helvetica",
                                  NSFontDescriptor.AttributeName.size : NSNumber(value:fontSize),
                                  NSAttributedString.Key.foregroundColor : labelColor] as [AnyHashable : Any]
                
                //  Draw each label
                let dimensionStrings = ["Dim. 1", "Dim. 2", "Dim. 3", "Dim. 4", "Sample"]
                for repeatInfo in repeatList {
                    //  Get the label string
                    var label = dimensionStrings[repeatInfo.dimension]
                    label += " : [\(repeatInfo.repeatLength)]"
                    
                    //  Get the size of the label
                    var attributedString = NSAttributedString(string: label, attributes: attributes as? [NSAttributedString.Key : Any])
                    var labelSize = attributedString.size()
                    
                    //  If the label doesn't fit in the repeat area, remove the repeat count
                    if (labelSize.width > (repeatInfo.endLoc - repeatInfo.startLoc)) {
                        label = dimensionStrings[repeatInfo.dimension]
                        attributedString = NSAttributedString(string: label, attributes: attributes as? [NSAttributedString.Key : Any])
                        labelSize = attributedString.size()
                    }
                    
                    //  Draw the label
                    let xPos : CGFloat = (repeatInfo.startLoc + repeatInfo.endLoc - labelSize.width) * 0.5
                    let yPos = bounds.size.height - labelSize.height - (bounds.size.height * 0.2 * CGFloat(repeatInfo.repeatLevel))
                    attributedString.draw(at: NSMakePoint(xPos, yPos))
                    
                    //  Draw dimension lines
                    NSColor.blue.set()
                    var oLinePath = NSBezierPath()
                    oLinePath.move(to: NSMakePoint(xPos - 2.0, yPos + (labelSize.height * 0.5)))
                    oLinePath.line(to: NSMakePoint(repeatInfo.startLoc - 1.0, yPos + (labelSize.height * 0.5)))
                    oLinePath.lineWidth = 1.0
                    oLinePath.stroke()
                    
                    oLinePath = NSBezierPath()
                    oLinePath.move(to: NSMakePoint(repeatInfo.startLoc + 1.0, yPos))
                    oLinePath.line(to: NSMakePoint(repeatInfo.startLoc + 1.0, yPos + labelSize.height))
                    oLinePath.lineWidth = 1.0
                    oLinePath.stroke()
                    
                    var oTrianglePath = NSBezierPath()
                    oTrianglePath.move(to: NSMakePoint(repeatInfo.startLoc + 1.0, yPos + (labelSize.height * 0.5)))
                    oTrianglePath.line(to: NSMakePoint(repeatInfo.startLoc + 6.0, yPos + (labelSize.height * 0.5) + 2.0))
                    oTrianglePath.line(to: NSMakePoint(repeatInfo.startLoc + 6.0, yPos + (labelSize.height * 0.5) - 2.0))
                    oTrianglePath.fill()

                    oLinePath = NSBezierPath()
                    oLinePath.move(to: NSMakePoint(xPos + 2.0 + labelSize.width, yPos + (labelSize.height * 0.5)))
                    oLinePath.line(to: NSMakePoint(repeatInfo.endLoc + 1.0, yPos + (labelSize.height * 0.5)))
                    oLinePath.lineWidth = 1.0
                    oLinePath.stroke()
                    
                    oLinePath = NSBezierPath()
                    oLinePath.move(to: NSMakePoint(repeatInfo.endLoc - 1.0, yPos))
                    oLinePath.line(to: NSMakePoint(repeatInfo.endLoc - 1.0, yPos + labelSize.height))
                    oLinePath.lineWidth = 1.0
                    oLinePath.stroke()
                    
                    oTrianglePath = NSBezierPath()
                    oTrianglePath.move(to: NSMakePoint(repeatInfo.endLoc - 1.0, yPos + (labelSize.height * 0.5)))
                    oTrianglePath.line(to: NSMakePoint(repeatInfo.endLoc - 6.0, yPos + (labelSize.height * 0.5) + 2.0))
                    oTrianglePath.line(to: NSMakePoint(repeatInfo.endLoc - 6.0, yPos + (labelSize.height * 0.5) - 2.0))
                    oTrianglePath.fill()
               }
            }
        }
    }
    
    func drawChunksIn(_ array : [DataChunk], repeatLevel : Int) {
        //  Get a font for the labels
        let fontSize = Double(5 - repeatLevel) * Double(bounds.size.height) * 0.2 * 0.9
        let labelColor = NSColor.darkGray
        let attributes = [NSFontDescriptor.AttributeName.name : "Helvetica",
                          NSFontDescriptor.AttributeName.size : NSNumber(value:fontSize),
                          NSAttributedString.Key.foregroundColor : labelColor] as [AnyHashable : Any]
        
        for chunk in array {
            if (chunk.type == .Repeat) {
                if (repeatLevel >= maxRepeatLevel) { maxRepeatLevel = repeatLevel }
                let repeatStart = xStart
                
                //  Draw the chunks recursively
                drawChunksIn(chunk.repeatChunks!, repeatLevel: repeatLevel + 1)
                
                //  Create a repeat info block to label the repeat later
                let dimension = chunk.format.rawValue - DataFormatType.rDimension1.rawValue
                let repeatInfo = RepeatInfo(startLoc: repeatStart, endLoc: xStart, repeatLevel: repeatLevel, dimension: dimension, repeatLength : chunk.length)
                repeatList.append(repeatInfo)
            }
            else if (chunk.type != .SetDimension) {
                //  Get a rectangle for this chunk
                let width = CGFloat(chunk.length) * bounds.width / CGFloat(totalLength)
                let height = bounds.size.height * CGFloat(5 - repeatLevel) * 0.2
                let rect = NSMakeRect(xStart, 0, width, height)
                
                //  Fill with the type color
                dataParser!.getChunkColor(chunk).set()
                rect.fill()
                
                //  Draw a dark-grey rectangle outline
                rect.insetBy(dx: 1.0, dy: 1.0)
                let path = NSBezierPath(rect: rect)
                path.lineWidth = 2.0
                NSColor.darkGray.set()
                path.stroke()
                
                //  Get the label string
                let label = dataParser!.getChunkLabel(chunk)
                
                //  Get the size of the label
                let attributedString = NSAttributedString(string: label, attributes: attributes as? [NSAttributedString.Key : Any])
                let labelSize = attributedString.size()
                
                //  Draw the label
                let xPos = xStart + (width - labelSize.width) * 0.5
                let yPos = (height - labelSize.height) * 0.5
                attributedString.draw(at: NSMakePoint(xPos, yPos))
                 
                //  Advance the position
                xStart += width
            }
        }
    }
    
}
