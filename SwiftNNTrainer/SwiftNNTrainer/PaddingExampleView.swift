//
//  PaddingExampleView.swift
//  SwiftNNTrainer
//
//  Created by Kevin Coble on 2/22/19.
//  Copyright © 2019 Kevin Coble. All rights reserved.
//

import Cocoa
import MetalPerformanceShaders
import MetalKit

class PaddingExampleView: NSView {
    
    var controller : PaddingViewController?
    
    var xOutputSize = 5
    var yOutputSize = 5
    
    let topBottomLabelChars =  ["a", "d", "g", "j", "m", "q", "t"]
    let leftRightLabelChars =  ["b", "e", "h", "k", "n", "r", "u"]
    let cornerLabelChars =     ["c", "f", "i", "l", "p", "s", "v"]

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        //  Erase the background
        NSColor.textBackgroundColor.set()
        bounds.fill()
        
        //  Get the half-kernels (extension if padding)
        let halfKernelX = (controller!.kernelX - 1) / 2
        let halfKernelY = (controller!.kernelY - 1) / 2

        let drawSource = (identifier == NSUserInterfaceItemIdentifier(rawValue: "Source"))
        if (drawSource) {
            //  Get the padding in each dimension
            var leftPadding = 0
            if (controller!.XPaddingMethod != .ValidOnly) { leftPadding = halfKernelX }
            if (controller!.XPaddingMethod == .SizeFull) { leftPadding = controller!.kernelX - 1 }
            var topPadding = 0
            if (controller!.YPaddingMethod != .ValidOnly) { topPadding = halfKernelY }
            if (controller!.YPaddingMethod == .SizeFull) { topPadding = controller!.kernelY - 1 }
            var rightPadding = 0
            if (controller!.XPaddingMethod != .ValidOnly) { rightPadding = halfKernelX }
            if (controller!.XPaddingMethod == .SizeFull) { rightPadding = controller!.kernelX - 1 }
            var bottomPadding = 0
            if (controller!.YPaddingMethod != .ValidOnly) { bottomPadding = halfKernelY }
            if (controller!.YPaddingMethod == .SizeFull) { bottomPadding = controller!.kernelY - 1 }

            //  Get the size of the example input with padding
            let xSize = controller!.currentExampleXSize + leftPadding + rightPadding
            let ySize = controller!.currentExampleYSize + topPadding + bottomPadding

            let xMargin : CGFloat = 10.0
            let yMargin : CGFloat = 10.0
            let rect = bounds.insetBy(dx: xMargin, dy: yMargin)

            let xDataWidth = rect.width / CGFloat(xSize)
            let yDataHeight = rect.height / CGFloat(ySize)

            //  Fill the source area with green
            NSColor.green.set()
            rect.fill()
            
            //  Fill any padding areas with yellow
            NSColor.yellow.set()
            if (leftPadding > 0) {
                let padWidth = xDataWidth * CGFloat(leftPadding)
                let padRect = NSRect(x: xMargin, y: yMargin, width: padWidth, height: bounds.height - 2.0 * yMargin)
                padRect.fill()
            }
            if (rightPadding > 0) {
                let padWidth = xDataWidth * CGFloat(rightPadding)
                let padRect = NSRect(x: bounds.width - xMargin - padWidth, y: yMargin, width: padWidth, height: bounds.height - 2.0 * yMargin)
                padRect.fill()
            }
            if (bottomPadding > 0) {
                let padHeight = yDataHeight * CGFloat(bottomPadding)
                let padRect = NSRect(x: xMargin, y: yMargin, width: bounds.width - 2.0 * xMargin, height: padHeight)
                padRect.fill()
            }
            if (topPadding > 0) {
                let padHeight = yDataHeight * CGFloat(topPadding)
                let padRect = NSRect(x: xMargin, y: bounds.height - yMargin - padHeight, width: bounds.width - 2.0 * xMargin, height: padHeight)
                padRect.fill()
            }

            //  Get the largest half-kernel for labeling limits
            var largestHalfKernel = halfKernelX
            if (halfKernelY > largestHalfKernel) { largestHalfKernel = halfKernelY }
            if (largestHalfKernel > 7) { largestHalfKernel = 7}

            var labelData = false
            if (controller!.edgeMode == .clamp) { labelData = true }
            if #available(OSX 10.14.1, *) {
                if (controller!.edgeMode == .mirror || controller!.edgeMode == .mirrorWithEdge) { labelData = true }
            } else {
                // Fallback on earlier versions
            }
            
            var xPos : CGFloat
            var yPos : CGFloat = rect.height + yMargin - yDataHeight
            NSColor.darkGray.set()
            let fontSize = (26.0 * CGFloat(24 - xSize) / 23.0) + 4.0
            let attributes = [NSAttributedString.Key.font : NSFont(name: "Helvetica", size: CGFloat(fontSize))!,
                              NSAttributedString.Key.foregroundColor : NSColor.darkGray] as [AnyHashable : Any]
            for y in 0..<ySize {
                xPos = rect.origin.x
                for x in 0..<xSize {
                    //  Draw a rectangle
                    let path = NSBezierPath(rect: NSRect(x: xPos, y: yPos, width: xDataWidth, height: yDataHeight))
                    path.lineWidth = 2.0
                    path.stroke()
                    
                    //  Label it
                    if (fontSize >= 4 && (controller!.XPaddingMethod != .ValidOnly || controller!.YPaddingMethod != .ValidOnly)) {
                        //  Get the label indexes for this position.  Going from outside-in, this results in -2, -1, 0, 1 for a padding of 2 and half-kernel of 2
                        var xLabelIndex = Int.max
                        if (x < leftPadding) { xLabelIndex = x - leftPadding }      //  In padding on left
                        else if (x - leftPadding < largestHalfKernel) { xLabelIndex = x - leftPadding }     //  In labeled data on left
                        if (x >= xSize - rightPadding) { xLabelIndex = xSize - x - (rightPadding + 1) }     //  In padding on right
                        else if (x >= xSize - rightPadding - largestHalfKernel) { xLabelIndex = xSize - rightPadding - x - 1 }     //  In labeled data on right
                        
                        var yLabelIndex = Int.max
                        if (y < bottomPadding) { yLabelIndex = y - bottomPadding }      //  In padding on bottom
                        else if (y - bottomPadding < largestHalfKernel) { yLabelIndex = y - bottomPadding }     //  In labeled data on bottom
                        if (y >= ySize - topPadding) { yLabelIndex = ySize - y - (topPadding + 1) }     //  In padding on top
                        else if (y >= ySize - topPadding - largestHalfKernel) { yLabelIndex = ySize - topPadding - y - 1 }     //  In labeled data on top

                        //  Get the label based on the position
                        var label = ""
                        //  Check for on the diagonal first
                        if (xLabelIndex != Int.max && xLabelIndex == yLabelIndex) {
                            if (xLabelIndex >= 0) { //  labelled data
                                if (labelData) { label = cornerLabelChars[xLabelIndex] }
                            }
                            else {      //  pad
                                label = getPadLabel(xIndex: xLabelIndex, yIndex: yLabelIndex)
                            }
                        }
                        //  Then check for the rest of the corner
                        else if (xLabelIndex != Int.max && yLabelIndex != Int.max) {
                            if (xLabelIndex < 0 || yLabelIndex < 0) {
                                //  In padding
                                label = getPadLabel(xIndex: xLabelIndex, yIndex: yLabelIndex)
                            }
                            else if (labelData) {
                                if (xLabelIndex < yLabelIndex) { label = leftRightLabelChars[xLabelIndex] }
                                else { label = topBottomLabelChars[yLabelIndex] }
                            }
                        }
                        //  On the left or right side
                        else if (xLabelIndex != Int.max) {
                            if (xLabelIndex >= 0) {     //  Labeled data
                                if (labelData) { label = leftRightLabelChars[xLabelIndex] }
                            }
                            else {      //  pad
                                label = getPadLabel(xIndex: xLabelIndex, yIndex: yLabelIndex)
                            }
                        }
                        //  On the top or bottom
                        else if (yLabelIndex != Int.max) {
                            if (yLabelIndex >= 0) {     //  Labeled data
                                if (labelData) { label = topBottomLabelChars[yLabelIndex] }
                            }
                            else {      //  pad
                                label = getPadLabel(xIndex: xLabelIndex, yIndex: yLabelIndex)
                            }
                        }
                        
                        //  Draw the label
                        let attributedString = NSAttributedString(string: label, attributes: attributes as? [NSAttributedString.Key : Any])
                        let labelSize = attributedString.size()
                        attributedString.draw(at: NSMakePoint(xPos + (xDataWidth - labelSize.width) * 0.5, yPos + (yDataHeight - labelSize.height) * 0.5))
                    }
                    
                    xPos += xDataWidth
                }
                yPos -= yDataHeight
            }
            
            //  Determine the kernel start for the selected output location
            let kernelStartX = kernelStartForOutput(index: controller!.selectedX, method : controller!.XPaddingMethod, kernelSize : controller!.kernelX, stride: controller!.strideX, offset: controller!.XOffset)
            let kernelStartY = kernelStartForOutput(index: controller!.selectedY, method : controller!.YPaddingMethod, kernelSize : controller!.kernelY, stride: controller!.strideY, offset: controller!.YOffset)
            
            //  Get a rectangle for the kernel
            let kernelRect = NSRect(x: xMargin + xDataWidth * CGFloat(kernelStartX),
                                y: yMargin + yDataHeight * CGFloat(ySize - kernelStartY - controller!.kernelY),
                                width: xDataWidth * CGFloat(controller!.kernelX),
                                height: yDataHeight * CGFloat(controller!.kernelY))
            
            //  Draw the rectangle
            let path = NSBezierPath(rect: kernelRect)
            NSColor.blue.set()
            path.lineWidth = 2.0
            path.stroke()
        }
        else {
            //  Determine the output size
            xOutputSize = Layer.sizeGivenPadding(method : controller!.XPaddingMethod, sourceSize : controller!.currentExampleXSize, kernelSize : controller!.kernelX, stride: controller!.strideX, offset: controller!.XOffset, clip: controller!.clipWidth)
            yOutputSize = Layer.sizeGivenPadding(method : controller!.YPaddingMethod, sourceSize : controller!.currentExampleYSize, kernelSize : controller!.kernelY, stride: controller!.strideY, offset: controller!.YOffset, clip: controller!.clipHeight)

            let xMargin : CGFloat = 10.0
            let yMargin : CGFloat = 10.0
            let rect = bounds.insetBy(dx: xMargin, dy: yMargin)

            let xDataWidth = rect.width / CGFloat(xOutputSize)
            let yDataHeight = rect.height / CGFloat(yOutputSize)

            NSColor.red.set()
            rect.fill()
            
            var xPos : CGFloat
            var yPos : CGFloat = rect.height + 10.0 - yDataHeight
            NSColor.darkGray.set()
            let fontSize = 12.0
            let attributes = [NSAttributedString.Key.font : NSFont(name: "Helvetica", size: CGFloat(fontSize))!,
                              NSAttributedString.Key.foregroundColor : NSColor.darkGray] as [AnyHashable : Any]
            var highlightPath : NSBezierPath? = nil
            for y in 0..<yOutputSize {
                xPos = rect.origin.x
                for x in 0..<xOutputSize {
                    //  Draw a rectangle
                    let path = NSBezierPath(rect: NSRect(x: xPos, y: yPos, width: xDataWidth, height: yDataHeight))
                    path.lineWidth = 2.0
                    path.stroke()
                    if (x == controller!.selectedX && y == controller!.selectedY) {
                        highlightPath = path
                    }
                    
                    //  Label it
                    let label = "\(x),\(y)"
                    let attributedString = NSAttributedString(string: label, attributes: attributes as? [NSAttributedString.Key : Any])
                    let labelSize = attributedString.size()
                    attributedString.draw(at: NSMakePoint(xPos + (xDataWidth - labelSize.width) * 0.5, yPos + (yDataHeight - labelSize.height) * 0.5))

                    xPos += xDataWidth
                }
                yPos -= yDataHeight
            }
            if let path = highlightPath {
                NSColor.blue.set()
                path.stroke()
            }
        }
    }
    
    func getPadLabel(xIndex: Int, yIndex: Int) -> String
    {
        if (controller!.edgeMode == .zero) {
            return "0"
        }
        else if (controller!.edgeMode == .clamp) {
            //  If both in pad territory, return the corner
            if (xIndex <= 0 && yIndex <= 0) { return cornerLabelChars[0] }
            //  Otherwise, return the side that is in padding
            if (xIndex < 0) { return leftRightLabelChars[0] }
            if (yIndex < 0) { return topBottomLabelChars[0] }
        }
        else {
            if #available(OSX 10.14.1, *) {
                if (controller!.edgeMode == .constant) {
                    return "\(controller!.paddingConstant)"
                }
                else if (controller!.edgeMode == .mirror) {
                    //  If both in pad territory, return the corner
                    if (xIndex < 0 && yIndex < 0) { return cornerLabelChars[0] }
                    //  If only padded in one dimension here, mirror the level
                    if (xIndex < 0) {
                        let mirrorX = abs(xIndex) - 1
                        //  If Y not in pad, mirror the edges
                        if (yIndex == Int.max) { return leftRightLabelChars[mirrorX] }
                        //  Use the Y with the mirror X to find the label
                        if (yIndex == mirrorX) { return cornerLabelChars[yIndex] }
                        if (yIndex > mirrorX) { return leftRightLabelChars[mirrorX] }
                        return topBottomLabelChars[yIndex]
                    }
                    if (yIndex < 0) {
                        let mirrorY = abs(yIndex) - 1
                        //  If X not in pad, mirror the edges
                        if (xIndex == Int.max) { return topBottomLabelChars[mirrorY] }
                        //  Use the X with the mirror Y to find the label
                        if (xIndex == mirrorY) { return cornerLabelChars[xIndex] }
                        if (xIndex > mirrorY) { return topBottomLabelChars[mirrorY] }
                        return leftRightLabelChars[xIndex]
                    }
                }
                else if (controller!.edgeMode == .mirrorWithEdge) {
                    return "E"  //!!
                }
            }
         }
        return "?"
    }
    
    override func mouseUp(with event: NSEvent) {
        let inSource = (identifier == NSUserInterfaceItemIdentifier(rawValue: "Source"))
        if (inSource) {
        }
        else {
            //  Get the click location
            let location = convert(event.locationInWindow, to: self)
            
            //  Get the output location
            let xMargin : CGFloat = 10.0
            let yMargin : CGFloat = 10.0
            let rect = bounds.insetBy(dx: xMargin, dy: yMargin)
            let xDataWidth = rect.width / CGFloat(xOutputSize)
            let yDataHeight = rect.height / CGFloat(yOutputSize)
            let xLoc = (location.x - frame.origin.x - rect.origin.x) / xDataWidth
            if (xLoc < 0.0 || xLoc >= CGFloat(xOutputSize)) { return }
            let yLoc = (location.y - frame.origin.y - rect.origin.y) / yDataHeight
            if (yLoc < 0.0 || yLoc >= CGFloat(yOutputSize)) { return }

            //  Set the highlight location and redraw
            controller!.selectedX = Int(xLoc)
            controller!.selectedY = yOutputSize - Int(yLoc) - 1
            controller!.updateExampleViews()
        }
    }
    
    func kernelStartForOutput(index: Int, method : PaddingMethod, kernelSize : Int, stride: Int, offset: Int) -> Int
    {
        var start = 0
        
        switch (method) {
        case .ValidOnly:
            start = 0       //  No padding, so start at end
        case .SizeSame:
            start = index % stride
        case .SizeFull:
            start = 0       //  Start at beginning of padding
        case .Custom:
            start = offset
        }
        
        return index * stride + start
    }

}
