//
//  PlotView.swift
//  SwiftNNTrainer
//
//  Created by Kevin Coble on 2/12/19.
//  Copyright © 2019 Kevin Coble. All rights reserved.
//

import Cocoa

struct PlotConstants {
    static let PLOT_MARGIN : CGFloat = 15.0
    static let DATA_PLOT_SIZE : CGFloat = 1.0
    static let LABEL_FONT_SIZE = 10.0
    static let LABEL_FONT = "Helvetica"
    static let NUM_AXIS_LABELS = [10, 5, 4, 2]
    static let TICK_LENGTH : CGFloat = 3.0
}

struct PlotData {
    let points : [(x : CGFloat, y : CGFloat)]
    let connected : Bool
    let color : NSColor
}

class PlotView: NSView {
    
    var dXScaleMin : Double
    var dXScaleMax : Double
    var dYScaleMin : Double
    var dYScaleMax : Double
    var dXWidth : CGFloat
    var dYHeight : CGFloat
    var bShowAxis : Bool
    var bShowData : Bool
    var dXAxisPosition : CGFloat
    var dYAxisPosition : CGFloat
    var numXLabels : Int
    var numYLabels : Int
    var numYDecimals : Int

    //  Plotted data
    var plotData : [PlotData]

    override init(frame frameRect: NSRect)
    {
        dXScaleMin = 0.0
        dXScaleMax = 100.0
        dYScaleMin = 0.0
        dYScaleMax = 100.0
        dXWidth = frameRect.size.width
        dYHeight = frameRect.size.height
        bShowAxis = true
        bShowData = true
        dXAxisPosition = 0.0
        dYAxisPosition = 0.0
        numXLabels = PlotConstants.NUM_AXIS_LABELS[0]
        numYLabels = PlotConstants.NUM_AXIS_LABELS[0]
        numYDecimals = 1

        plotData = []

        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        dXScaleMin = 0.0
        dXScaleMax = 100.0
        dYScaleMin = 0.0
        dYScaleMax = 100.0
        dXWidth = 200.0
        dYHeight = 200.0
        bShowAxis = true
        bShowData = true
        dXAxisPosition = PlotConstants.PLOT_MARGIN
        dYAxisPosition = PlotConstants.PLOT_MARGIN
        numXLabels = PlotConstants.NUM_AXIS_LABELS[0]
        numYLabels = PlotConstants.NUM_AXIS_LABELS[0]
        numYDecimals = 1

        plotData = []

        super.init(coder: coder)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        //  Draw a background
        NSColor.white.set()
        dirtyRect.fill()
        
        //  If axis labels are selected, draw them first
        if (bShowAxis) {
            // Draw the X axis
            let axisColor = NSColor.blue
            var oAxisPath = NSBezierPath()
            oAxisPath.move(to: NSMakePoint(dYAxisPosition, dXAxisPosition))
            oAxisPath.line(to: NSMakePoint(dYAxisPosition + dXWidth, dXAxisPosition))
            axisColor.set()
            oAxisPath.lineWidth = 1.0
            oAxisPath.stroke()
            
            //  Draw the X axis labels
            var oTickPath = NSBezierPath()
            let oLabelFont = NSFont(name:PlotConstants.LABEL_FONT, size: CGFloat(PlotConstants.LABEL_FONT_SIZE))
            let attributes = [NSAttributedString.Key.font : oLabelFont!,
                              NSAttributedString.Key.foregroundColor : axisColor] as [AnyHashable : Any]
            for i in 0...numXLabels {
                let dTickValue = ((dXScaleMax - dXScaleMin) * Double(i) / Double(numXLabels)) + dXScaleMin
                let dTickLocation = getXPlotLoc(dTickValue)
                let oTickPath = NSBezierPath()
                oTickPath.move(to: NSMakePoint(dTickLocation, dXAxisPosition))
                oTickPath.line(to: NSMakePoint(dTickLocation, dXAxisPosition - PlotConstants.TICK_LENGTH))
                oTickPath.lineWidth = 1.0
                oTickPath.stroke()
                let sLabel = "\(dTickValue)"
                let attributedString = NSAttributedString(string:sLabel, attributes:attributes as? [NSAttributedString.Key : Any])
                let labelSize = attributedString.size()
                attributedString.draw(at: NSMakePoint(dTickLocation - labelSize.width * 0.5, dXAxisPosition - PlotConstants.TICK_LENGTH - labelSize.height))
            }

            // Draw the Y axis
            oAxisPath = NSBezierPath()
            oAxisPath.move(to: NSMakePoint(dYAxisPosition, dXAxisPosition))
            oAxisPath.line(to: NSMakePoint(dYAxisPosition, dXAxisPosition + dYHeight))
            oAxisPath.lineWidth = 1.0
            oAxisPath.stroke()
            
            //  Draw the Y axis labels
            for i in 0...numYLabels {
                let dTickValue = ((dYScaleMax - dYScaleMin) * Double(i) / Double(numYLabels)) + dYScaleMin
                let dTickLocation = getYPlotLoc(dTickValue)
                oTickPath = NSBezierPath()
                oTickPath.move(to: NSMakePoint(dYAxisPosition, dTickLocation))
                oTickPath.line(to: NSMakePoint(dYAxisPosition - PlotConstants.TICK_LENGTH, dTickLocation))
                oTickPath.lineWidth = 1.0
                oTickPath.stroke()
                let sLabel = String(format: "%.\(numYDecimals)f", dTickValue)
                let attributedString = NSAttributedString(string:sLabel, attributes:attributes as? [NSAttributedString.Key : Any])
                let labelSize = attributedString.size()
                attributedString.draw(at: NSMakePoint(dYAxisPosition - (PlotConstants.TICK_LENGTH + labelSize.width), dTickLocation - labelSize.height * 0.5))
            }
        }
        
        //  Plot each data set
        for plot in plotData {
            //  Set the color
            plot.color.set()

            //  Connected line
            if (plot.connected) {
                let count = plot.points.count
                if (count < 2) {continue}       //  Not enough points to plot
                //  Create the path
                let oPlotPath = NSBezierPath()
                
                //  Get the initial point
                let xValue = getXPlotLoc(Double(plot.points[0].x))
                let yValue = getYPlotLoc(Double(plot.points[0].y))
                oPlotPath.move(to: NSMakePoint(CGFloat(xValue), CGFloat(yValue)))

                //  Add each segment
                for i in 1..<count {
                    //  Get the location
                    let xValue = getXPlotLoc(Double(plot.points[i].x))
                    let yValue = getYPlotLoc(Double(plot.points[i].y))
                    oPlotPath.line(to: NSMakePoint(CGFloat(xValue), CGFloat(yValue)))
                }

                //  Draw the path
                oPlotPath.lineWidth = 1.0
                oPlotPath.stroke()

            }
            
            //  Individual data points
            else {
                for point in plot.points {
                    //  Get the x-axis value
                    let xValue = getXPlotLoc(Double(point.x))
                    //  Get the y-axis value
                    let yValue = getYPlotLoc(Double(point.y))
                    let oPlotPath = NSBezierPath(ovalIn:
                        NSMakeRect(CGFloat(xValue - PlotConstants.DATA_PLOT_SIZE), CGFloat(yValue - PlotConstants.DATA_PLOT_SIZE), CGFloat(2 * PlotConstants.DATA_PLOT_SIZE), CGFloat(2 * PlotConstants.DATA_PLOT_SIZE)))
                    oPlotPath.lineWidth = 1.0
                    oPlotPath.stroke()
                }
            }
        }
    }
    
    func getXPlotLoc(_ dXValue : Double) -> CGFloat
    {
        var dLocation = CGFloat((dXValue - dXScaleMin) / (dXScaleMax - dXScaleMin))
        dLocation *= dXWidth
        dLocation += dYAxisPosition
        return dLocation
    }
    func getYPlotLoc(_ dYValue : Double) -> CGFloat
    {
        var dLocation = CGFloat((dYValue - dYScaleMin) / (dYScaleMax - dYScaleMin))
        dLocation *= dYHeight
        dLocation += dXAxisPosition
        return dLocation
    }
    
    func calculateLabelInformation() -> Void
    {
        if (bShowAxis) {
            //  Get the number of decimal places for the Y values
            numYDecimals = 1
            if (dYScaleMax > dYScaleMin) {
                let logDiff = log(dYScaleMax - dYScaleMin)
                if (logDiff < 0) {
                    numYDecimals = Int(-floor(logDiff)) + 1
                }
            }
            
            //  Get the max Y label value size
            let oLabelFont = NSFont(name:PlotConstants.LABEL_FONT, size: CGFloat(PlotConstants.LABEL_FONT_SIZE))
            let fontAttributes = [NSAttributedString.Key.font : oLabelFont!]
            var yMaxLabelWidth : CGFloat = 0
            for i in 0...numYLabels {
                let dTickValue = abs(((dYScaleMax - dYScaleMin) * Double(i) / Double(numYLabels)) + dYScaleMin)
                let formattedString = String(format: "%.\(numYDecimals)f", dTickValue)
                let attributedString = NSAttributedString(string: formattedString, attributes:fontAttributes)
                let size = attributedString.size()
                if (size.width > yMaxLabelWidth) { yMaxLabelWidth = size.width }
            }

            //  Format the X min and max values
            let sXMinString = "\(dXScaleMin)"
            let sXMaxString = "\(dXScaleMax)"

            //  Get the size of the strings
            var attributedString = NSAttributedString(string: sXMinString, attributes:fontAttributes)
            let tXMinSize = attributedString.size()
            attributedString = NSAttributedString(string: sXMaxString, attributes:fontAttributes)
            let tXMaxSize = attributedString.size()

            //  Y axis offset will be the max of the Y axis labels and half the X Min axis label
            dYAxisPosition = tXMinSize.width * 0.5
            let yLabelWidth = yMaxLabelWidth + PlotConstants.TICK_LENGTH
            if (yLabelWidth > dYAxisPosition) { dYAxisPosition = yLabelWidth }
            dYAxisPosition += PlotConstants.PLOT_MARGIN
            
            //  The X axis offset will be the height of the X axis labels plus a tick mark
            dXAxisPosition = tXMinSize.height
            if (tXMaxSize.height > dXAxisPosition) { dXAxisPosition = tXMaxSize.height}
            dXAxisPosition += PlotConstants.TICK_LENGTH
            dXAxisPosition += PlotConstants.PLOT_MARGIN
            
            //  Width and height of the data plot are from the axis to the margin
            dXWidth = bounds.width - (dYAxisPosition + PlotConstants.PLOT_MARGIN)
            dYHeight = bounds.height - (dXAxisPosition + PlotConstants.PLOT_MARGIN)

            //  Determine the number of labels that will fit
            var numIndex = 0
            var maxXLabelSize = tXMinSize.width
            if (tXMaxSize.width > maxXLabelSize) { maxXLabelSize = tXMaxSize.width }
            maxXLabelSize += PlotConstants.TICK_LENGTH       //  Add a tick-marks worth of spacing minimum between labels
            while (numIndex < PlotConstants.NUM_AXIS_LABELS.count-1) {
                if (CGFloat(PlotConstants.NUM_AXIS_LABELS[numIndex]+1) * maxXLabelSize <= dXWidth) { break }
                numIndex += 1
            }
            numXLabels = PlotConstants.NUM_AXIS_LABELS[numIndex]
            numIndex = 0
            while (numIndex < PlotConstants.NUM_AXIS_LABELS.count-1) {
                if (CGFloat(PlotConstants.NUM_AXIS_LABELS[numIndex]+1) * (tXMinSize.height + tXMaxSize.height) * 0.5 <= dYHeight) { break }
                numIndex += 1
            }
            numYLabels = PlotConstants.NUM_AXIS_LABELS[numIndex]
        }
        else {
            dXAxisPosition = PlotConstants.PLOT_MARGIN
            dYAxisPosition = PlotConstants.PLOT_MARGIN
            
            //  Width and height of the data plot are from the axis to the margin
            dXWidth = bounds.width - (dYAxisPosition + PlotConstants.PLOT_MARGIN)
            dYHeight = bounds.height - (dXAxisPosition + PlotConstants.PLOT_MARGIN)
        }
    }
    
    func scaleToData()
    {
        //  Verify we have plot data
        if (plotData.count < 0) { return }
        
        //  Initialize the limits to extremes
        dXScaleMin = Double.infinity
        dXScaleMax = -Double.infinity
        dYScaleMin = Double.infinity
        dYScaleMax = -Double.infinity

        //  Scale for all plot sets
        for plot in plotData {
            var xMin = CGFloat.infinity
            var xMax = -CGFloat.infinity
            var yMin = CGFloat.infinity
            var yMax = -CGFloat.infinity
            for point in plot.points {
                if (point.x < xMin) { xMin = point.x }
                if (point.x > xMax) { xMax = point.x }
                if (point.y < yMin) { yMin = point.y }
                if (point.y > yMax) { yMax = point.y }
            }
            
            //  Get the human-readable scales
            let roundedXVarRange = PlotView.roundScaleLimitsMin(limits: (min:Double(xMin), max:Double(xMax)), usingLogScale:false)
            let roundedYVarRange = PlotView.roundScaleLimitsMin(limits: (min:Double(yMin), max:Double(yMax)), usingLogScale:false)
            
            if (roundedXVarRange.min < dXScaleMin) { dXScaleMin = roundedXVarRange.min }
            if (roundedXVarRange.max > dXScaleMax) { dXScaleMax = roundedXVarRange.max }
            if (roundedYVarRange.min < dYScaleMin) { dYScaleMin = roundedYVarRange.min }
            if (roundedYVarRange.max > dYScaleMax) { dYScaleMax = roundedYVarRange.max }
        }
    }
    
    class func roundScaleLimitsMin(limits:(min:Double, max:Double), usingLogScale : Bool) -> (min:Double, max:Double)
    {
        
        //  Set the temporary limit values
        var upper = limits.max
        var lower = limits.min
        
        //  If logarithmic, just round the min and max to the nearest power of 10
        if (usingLogScale) {
            //  Round the upper limit
            if (upper <= 0.0) {upper = 1000.0}
            var Y = log10(upper)
            var Z = Int(Y)
            if (Y != Double(Z) && Y > 0.0) {Z += 1}
            upper = pow(10.0, Double(Z))
            
            //  round the lower limit
            if (lower <= 0.0) {lower = 0.1}
            Y = log10(lower)
            Z = Int(Y)
            if (Y != Double(Z) && Y < 0.0) {Z -= 1}
            lower = pow(10.0, Double(Z))
            
            //  Make sure the limits are not the same
            if (lower == upper) {
                Y = log10(upper)
                upper = pow(10.0, Y+1.0)
                lower = pow(10.0, Y-1.0)
            }
            
            return (min:lower, max:upper)
        }
        
        
        //  Get the difference between the limits
        var bRoundLimits = true
        while (bRoundLimits) {
            bRoundLimits = false
            let difference = upper - lower
            if (!difference.isFinite) {
                lower = 0.0
                upper = 0.0
                return (min:lower, max:upper)
            }
            
            //  Calculate the upper limit
            if (upper != 0.0) {
                //  Convert negatives to positives
                var bNegative = false
                if (upper < 0.0) {
                    bNegative = true
                    upper *= -1.0
                }
                //  If the limits match, use value for rounding
                var Z : Double
                if (difference == 0.0) {
                    Z = floor(log10(upper))
                    if (Z < 0.0) {Z -= 1}
                    Z -= 1
                }
                    //  If the limits don't match, use difference for rounding
                else {
                    Z = floor(log10(difference))
                }
                //  Get the normalized limit
                var Y = upper / pow(10.0, Z)
                //  Make sure we don't round down due to value storage limitations
                let NY = Y + Double(Float.ulpOfOne) * 100.0
                if (floor(log10(Y)) != floor(log10(NY))) {
                    Y = NY * 0.1
                    Z += 1
                }
                //  Round by integerizing the normalized number
                if (Y != floor(Y)) {
                    Y = floor(Y)
                    if (!bNegative) {
                        Y += 1.0
                    }
                    upper = Y * pow(10.0, Z)
                }
                if (bNegative) {upper *= -1.0}
            }
            
            
            //  Calculate the lower limit
            if (lower != 0.0) {
                //  Convert negatives to positives
                var bNegative = false
                if (lower < 0.0) {
                    bNegative = true
                    lower *= -1.0
                }
                //  If the limits match, use value for rounding
                var Z : Double
                if (difference == 0.0) {
                    Z = floor(log10(lower))
                    if (Z < 0.0) {Z -= 1}
                    Z += 1
                }
                    //  If the limits don't match, use difference for rounding
                else {
                    Z = floor(log10(difference))
                }
                //  Get the normalized limit
                var Y = lower / pow(10.0, Z)
                //  Make sure we don't round down due to value storage limitations
                let NY = Y + Double(Float.ulpOfOne) * 100.0
                if (Int(log10(Y)) != Int(log10(NY))) {
                    Y = NY * 0.1
                    Z += 1
                }
                //  Round by integerizing the normalized number
                if (Y != floor(Y)) {
                    Y = floor(Y)
                    if (bNegative) {
                        Y += 1.0
                    }
                    else {
                        if (difference == 0.0) {Y -= 1.0}
                    }
                    lower = Y * pow(10.0, Z)
                }
                if (bNegative) {lower *= -1.0}
                
                //  Make sure both are not 0
                if (upper == 0.0 && lower == 0.0) {
                    upper = 1.0
                    lower = -1.0
                }
                
                //  If the limits still match offset by a percent each and recalculate
                if (upper == lower) {
                    if (lower > 0.0) {
                        lower *= 0.99
                    }
                    else {
                        lower *= 1.01
                    }
                    if (upper > 0.0) {
                        upper *= 1.01
                    }
                    else {
                        upper *= 0.99
                    }
                    bRoundLimits = true
                }
            }
        }
        
        return (min:lower, max:upper)
    }
}
