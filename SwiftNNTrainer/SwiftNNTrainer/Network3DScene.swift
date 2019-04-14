//
//  Network3DScene.swift
//  SwiftNNTrainer
//
//  Created by Kevin Coble on 2/7/19.
//  Copyright © 2019 Kevin Coble. All rights reserved.
//

import Cocoa
import SceneKit

class Network3DScene: SCNScene {
    
    var use_XxY_for_1x1xN = true
    var outputBlockScale : CGFloat = 1.0
    
    let cameraNode = SCNNode()
    var currentCameraSpan : CGFloat = 15
    var cameraZoomScale : CGFloat = 10.0
    let maxNetworkSize :CGFloat = 20000.0
    var addedNodes : [SCNNode] = []
    
    var flowSizes : [SCNVector3]?
    var totalWidthsForFlows : [CGFloat]?
    var flowLocations : [CGPoint]?  //  (y = z location)

    override init() {
        super.init()
        
        //  Create a camera
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3Make(-currentCameraSpan * 0.01, currentCameraSpan * 0.3, currentCameraSpan * 1.5)
        self.rootNode.addChildNode(cameraNode)
        cameraNode.camera!.zFar = Double(maxNetworkSize * 2.0)
        cameraNode.rotation = SCNVector4Make(1.0, 0.0, 0.0, CGFloat.pi / -7.0)
        
        //  Create a light
        let sunNode = SCNNode()
        sunNode.light = SCNLight()
        sunNode.light!.type = SCNLight.LightType.omni
        sunNode.light!.color = NSColor(white: 0.75, alpha: 1.0)
        sunNode.position = SCNVector3Make(20000.0, 16000.0, 30000.0)
        self.rootNode.addChildNode(sunNode)
        let ambientNode = SCNNode()
        ambientNode.light = SCNLight()
        ambientNode.light!.type = SCNLight.LightType.ambient
        ambientNode.light!.color = NSColor(white: 0.3, alpha: 1.0)
        self.rootNode.addChildNode(ambientNode)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setFromDocument(document : DocumentData)
    {
        //  Remove any added nodes
        for node in addedNodes {
            node.removeFromParentNode()
        }
        addedNodes.removeAll()
        
        //  Get the size of each flow
        flowSizes = [SCNVector3](repeatElement(SCNVector3(0, 0, 0), count: document.flows.count))
        for index in 0..<document.flows.count {
            flowSizes![index] = getFlowDisplaySize(document.flows[index])
        }
        
        //  Get the total width of everything upstream from each flow (0 if nothing upstream)
        totalWidthsForFlows = [CGFloat](repeating: 0.0, count: document.flows.count)
        getTotalWidthOfFlow(flowIndex: document.outputFlow, document: document)
        
        //  Get a relative x-z coordinate for each flow (store in CGPoint with y = z)
        flowLocations  = [CGPoint](repeatElement(CGPoint(x: 0, y: 0), count: document.flows.count))
        getRelativeLocation(flowIndex: document.outputFlow, document: document)
        
        //  Find the leftmost point
        var leftMost : CGFloat = CGFloat.infinity
        for index in 0..<document.flows.count {
            let left = flowLocations![index].x - flowSizes![index].x
            if (left < leftMost) { leftMost = left }
        }
        
        //  Offset the positions to center the diagram
        for index in 0..<document.flows.count {
            flowLocations![index].x -= leftMost * 0.5
        }

        //  Draw each flow
        for flowIndex in 0..<document.flows.count {
            let flow = document.flows[flowIndex]
            
            //  Get the start location for the input block
            var xPosition = flowLocations![flowIndex].x - flowSizes![flowIndex].x
            var flowInputDimensions = document.getFlowInputDimensions(flowIndex: flowIndex)
            var flowInputDisplaySize = getDisplayDimensions(forDimensions: flowInputDimensions)

            //  If more than one input, draw an output block and then a skewed box from the output of each 'input flow' to this flow's input block
            if (flow.inputs.count > 1) {
                for input in flow.inputs {
                    if (input.type == .Flow) {
                        //  Output block
                        let outputDimensions = getDisplayDimensions(forDimensions: document.flows[input.index].currentOutputSize)
                        let outputGeometry = createBox(width: CGFloat(outputDimensions[2]), height: CGFloat(outputDimensions[1]), length: CGFloat(outputDimensions[0]), xScale: outputBlockScale)
                        if let material = createFeatureTexture(color: NSColor.yellow) {
                            outputGeometry.materials = [material]
                        }
                        else {
                            outputGeometry.firstMaterial!.diffuse.contents = NSColor.yellow
                        }
                        let outputNode = SCNNode(geometry: outputGeometry)
                        var xPos = flowLocations![input.index].x + (CGFloat(outputDimensions[2]) * 0.5 * outputBlockScale)
                        outputNode.position = SCNVector3Make(xPos, 0.0, flowLocations![input.index].y)
                        self.rootNode.addChildNode(outputNode)
                        addedNodes.append(outputNode)
                        xPos += CGFloat(outputDimensions[2]) * 0.5 * outputBlockScale     //  X coord right of the flow output block
                        
                        //  Skew box
                        let width = xPosition - xPos
                        let zSkew = flowLocations![flowIndex].y - flowLocations![input.index].y
                        let skewGeometry = createSkewedSquareTube(width: width, height: CGFloat(flowInputDisplaySize[1]), length: CGFloat(flowInputDisplaySize[0]), rightHeightOffset: 0.0, rightLengthOffset: zSkew)
                        skewGeometry.firstMaterial!.diffuse.contents = NSColor.blue
                        skewGeometry.firstMaterial!.isDoubleSided = true
                        let skewNode = SCNNode(geometry: skewGeometry)
                        skewNode.position = SCNVector3Make(xPosition - width * 0.5, 0.0, flowLocations![input.index].y)
                        self.rootNode.addChildNode(skewNode)
                        addedNodes.append(skewNode)
                    }
                }
            }
            
            //  Add the input volume
            let inputGeometry = createBox(width: CGFloat(flowInputDisplaySize[2]), height: CGFloat(flowInputDisplaySize[1]), length: CGFloat(flowInputDisplaySize[0]), xScale: 1.0)
            var color = NSColor.yellow       //  Yellow for intermediate inputs
            if (flow.usesOnlyDataInput) { color = NSColor.green }  //  Green for initial inputs
            if let material = createFeatureTexture(color: color) {
                inputGeometry.materials = [material]
            }
            else {
                inputGeometry.firstMaterial!.diffuse.contents = color
            }
            let inputNode = SCNNode(geometry: inputGeometry)
            xPosition += CGFloat(flowInputDisplaySize[2]) * 0.5
            inputNode.position = SCNVector3Make(xPosition, 0.0, flowLocations![flowIndex].y)
            self.rootNode.addChildNode(inputNode)
            addedNodes.append(inputNode)
            if let layer = flow.layers.first {
                addInputPadding(layer: layer, xPos: xPosition, inputDimensions: flowInputDimensions, zOffset : flowLocations![flowIndex].y, xScale: 1.0)
            }
            xPosition += CGFloat(flowInputDisplaySize[2]) * 0.5
            
            //  Draw each layer
            var outputDimensions = [0, 0, 0, 0]
            var outputDisplaySize = [0, 0, 0, 0]
            var layerIndex = 0
            for layer in flow.layers {
                if (layer.type == .Neuron || layer.type == .SoftMax || layer.type == .Normalization) {
                    //  Layers that don't change the data dimensions get a small slab, without intervening data block
                    let intermediateGeometry = SCNBox(width: 0.5, height: CGFloat(flowInputDisplaySize[1]), length: CGFloat(flowInputDisplaySize[0]), chamferRadius: 0.0)
                    intermediateGeometry.firstMaterial!.diffuse.contents = NSColor.cyan
                    let intermediateNode = SCNNode(geometry: intermediateGeometry)
                    xPosition += 0.25
                    intermediateNode.position = SCNVector3Make(xPosition, 0.0, flowLocations![flowIndex].y)
                    self.rootNode.addChildNode(intermediateNode)
                    addedNodes.append(intermediateNode)
                    xPosition += 0.25
    
                    //  Animate the slab if the layer is selected
                    if (layer.selected) {
                        let duration : TimeInterval = 1
                        let action1 = SCNAction.customAction(duration: duration, action: { (node, elapsedTime) in
                            let percentage = elapsedTime / CGFloat(duration)
                            node.geometry?.firstMaterial?.diffuse.contents = self.animateColor(from: NSColor.cyan, to: NSColor.magenta, percentage: percentage)
                        })
                        let action2 = SCNAction.customAction(duration: duration, action: { (node, elapsedTime) in
                            let percentage = elapsedTime / CGFloat(duration)
                            node.geometry?.firstMaterial?.diffuse.contents = self.animateColor(from: NSColor.magenta, to: NSColor.cyan, percentage: percentage)
                        })
                        let action = SCNAction.repeatForever(SCNAction.sequence([action1, action2]))
                        intermediateNode.runAction(action)
                    }
                }
                else {
                    //  If there was a previous output, add the output block
                    if (outputDimensions[0] != 0) {
                        let intermediateGeometry = createBox(width: CGFloat(outputDisplaySize[2]), height: CGFloat(outputDisplaySize[1]), length: CGFloat(outputDisplaySize[0]), xScale: outputBlockScale)
                        if let material = createFeatureTexture(color: NSColor.yellow) {
                            intermediateGeometry.materials = [material]
                        }
                        else {
                            intermediateGeometry.firstMaterial!.diffuse.contents = NSColor.yellow
                        }
                        let intermediateNode = SCNNode(geometry: intermediateGeometry)
                        xPosition += CGFloat(outputDisplaySize[2]) * 0.5 * outputBlockScale
                        intermediateNode.position = SCNVector3Make(xPosition, 0.0, flowLocations![flowIndex].y)
                        self.rootNode.addChildNode(intermediateNode)
                        addedNodes.append(intermediateNode)
                        addInputPadding(layer: layer, xPos: xPosition, inputDimensions: outputDimensions, zOffset: flowLocations![flowIndex].y, xScale: outputBlockScale)
                        xPosition += CGFloat(outputDisplaySize[2]) * 0.5 * outputBlockScale
                    }

                    //  Get the padded input size
                    let padding = layer.getPaddingSize()
                    let paddedWidth = flowInputDisplaySize[0] + padding.left + padding.right
                    let paddedHeight = flowInputDisplaySize[1] + padding.top + padding.bottom
                    
                    //  Get the dimensions of the outside of the layer
                    outputDimensions = layer.getOutputDimensionGivenInput(dimensions: flowInputDimensions)
                    outputDisplaySize = getDisplayDimensions(forDimensions: outputDimensions)
    
                    //  Get the sizes for the frustum for the layer
                    var width : CGFloat = 1.0
                    var maxDiff = abs(paddedWidth - outputDisplaySize[0])
                    if (abs(paddedHeight - outputDisplaySize[1]) > maxDiff) { maxDiff = abs(paddedHeight - outputDisplaySize[1]) }
                    if (maxDiff > 3) {
                        width += CGFloat(maxDiff - 2) * 0.25
                    }
    
                    //  Add a frustum for the layer
                    let frustumGeometry = createFrustum(bottomWidth: CGFloat(paddedWidth), bottomHeight: CGFloat(paddedHeight), length: width, topWidth: CGFloat(outputDisplaySize[0]), topHeight: CGFloat(outputDisplaySize[1]))
                    frustumGeometry.firstMaterial!.diffuse.contents = NSColor.blue
                    frustumGeometry.firstMaterial!.isDoubleSided = true
                    let frustumNode = SCNNode(geometry: frustumGeometry)
                    xPosition += CGFloat(width) * 0.5
                    frustumNode.rotation = SCNVector4Make(0.0, 1.0, 0.0, CGFloat.pi * 0.5)
                    frustumNode.position = SCNVector3Make(xPosition, 0.0, flowLocations![flowIndex].y)
                    self.rootNode.addChildNode(frustumNode)
                    frustumNode.name = "Flow\(flowIndex)Layer\(layerIndex)"
                    addedNodes.append(frustumNode)
                    xPosition += CGFloat(width) * 0.5
    
                    //  Animate the frustum if the layer is selected
                    if (layer.selected) {
                        let duration : TimeInterval = 1
                        let action1 = SCNAction.customAction(duration: duration, action: { (node, elapsedTime) in
                            let percentage = elapsedTime / CGFloat(duration)
                            node.geometry?.firstMaterial?.diffuse.contents = self.animateColor(from: NSColor.blue, to: NSColor.magenta, percentage: percentage)
                        })
                        let action2 = SCNAction.customAction(duration: duration, action: { (node, elapsedTime) in
                            let percentage = elapsedTime / CGFloat(duration)
                            node.geometry?.firstMaterial?.diffuse.contents = self.animateColor(from: NSColor.magenta, to: NSColor.blue, percentage: percentage)
                        })
                        let action = SCNAction.repeatForever(SCNAction.sequence([action1, action2]))
                        frustumNode.runAction(action)
                    }

                    //  Update the inputs for the next layer
                    flowInputDimensions = outputDimensions
                    flowInputDisplaySize = outputDisplaySize
                }
                layerIndex += 1
            }
        }
        
        //  Add the output volume
        let outputDisplaySize = getDisplayDimensions(forDimensions: document.outputDimensions)
        let outputGeometry = createBox(width: CGFloat(outputDisplaySize[2]), height: CGFloat(outputDisplaySize[1]), length: CGFloat(outputDisplaySize[0]), xScale: 1.0)
        if let material = createFeatureTexture(color: NSColor.red) {
            outputGeometry.materials = [material]
        }
        else {
            outputGeometry.firstMaterial!.diffuse.contents = NSColor.red
        }
        let outputNode = SCNNode(geometry: outputGeometry)
        outputNode.position = SCNVector3Make((CGFloat(outputDisplaySize[2]) - leftMost) * 0.5, 0.0, 0.0)
        self.rootNode.addChildNode(outputNode)
        addedNodes.append(outputNode)
        

        //  If the total width is larger than the camera span, move the camera back
        if (abs(leftMost) > currentCameraSpan) {
            currentCameraSpan = abs(leftMost)
            cameraNode.position = SCNVector3Make(-currentCameraSpan * 0.01, currentCameraSpan * 0.3, currentCameraSpan * 1.5)
        }
    }
    
    func getFlowDisplaySize(_ flow : Flow) -> SCNVector3
    {
        //  Start with the input box size
        var inputDisplaySize = getDisplayDimensions(forDimensions: flow.currentInputSize)
        var flowSize = SCNVector3(inputDisplaySize[2], inputDisplaySize[1], inputDisplaySize[0])

        //  Add each layer into the dimensions
        var dimensions = flow.currentInputSize
        var outputDimensions = [0, 0, 0, 0]
        var outputDisplaySize = [0, 0, 0, 0]
        for layer in flow.layers {
            if (layer.type == .Neuron || layer.type == .SoftMax || layer.type == .Normalization) {
                flowSize.x += 0.5        //  layers that don't change the data dimensions get a small slab, without intervening data block
            }
            else {
                //  If a previous output block, add as an intermediate block
                if (outputDimensions[0] != 0) {
                    flowSize.x += CGFloat(outputDisplaySize[2]) * outputBlockScale
                    //  Other dimensions checked after padding later
                }
                
                //  Add the width of the layer
                outputDimensions = layer.getOutputDimensionGivenInput(dimensions: dimensions)
                outputDisplaySize = getDisplayDimensions(forDimensions: outputDimensions)
                flowSize.x += 1.0       //  Basic frustum width
                var maxDiff = abs(inputDisplaySize[0] - outputDisplaySize[0])
                if (abs(inputDisplaySize[1] - outputDisplaySize[1]) > maxDiff) { maxDiff = abs(inputDisplaySize[1] - outputDisplaySize[1]) }
                if (maxDiff > 3) {
                    flowSize.x += CGFloat(maxDiff - 2) * 0.25       //  Extended frustum width
                }
                
                //  Get the padded sizes
                let padding = layer.getPaddingSize()
                let paddedY = CGFloat(outputDisplaySize[1] + padding.top + padding.bottom)
                let paddedZ = CGFloat(outputDisplaySize[0] + padding.left + padding.right)

                //  Increase height and length as needed
                if (paddedY > flowSize.y) { flowSize.y = paddedY }
                if (paddedZ > flowSize.z) { flowSize.z = paddedZ }

                //  Advance the dimensions
                dimensions = outputDimensions
                inputDisplaySize = outputDisplaySize
            }
        }
        
        return flowSize
    }
    
    func getTotalWidthOfFlow(flowIndex : Int, document : DocumentData)
    {
        let flow = document.flows[flowIndex]
        
        //  Get the total width of the inputs
        var totalInputWidth : CGFloat = 0.0
        for input in flow.inputs {
            if (input.type == .Input) {
                let inputDimensions = getDisplayDimensions(forDimensions: document.inputDimensions)
                totalInputWidth += CGFloat(inputDimensions[0]) + 5.0
            }
            else {
                if (totalWidthsForFlows![input.index] == 0) {
                    //  Not processed yet
                    getTotalWidthOfFlow(flowIndex : input.index, document : document)
                    totalInputWidth += totalWidthsForFlows![input.index] + 5.0
                }
                else {
                    //  Assume it was part of another input
                }
            }
        }
        totalInputWidth -= 5.0      //  Remove final inter-input spacing
        
        //  If the layers width is larger, use that
        if (flowSizes![flowIndex].z > totalInputWidth) { totalInputWidth = flowSizes![flowIndex].z }
        
        //  Store the size
        totalWidthsForFlows![flowIndex] = totalInputWidth
    }
    
    func getRelativeLocation(flowIndex : Int, document : DocumentData)
    {
        let flow = document.flows[flowIndex]
        
        //  Position each input flow
        var zLocation = totalWidthsForFlows![flowIndex] * -0.5
        for input in flow.inputs {
            if (input.type == .Input) {
                let inputDimensions = getDisplayDimensions(forDimensions: document.inputDimensions)
                zLocation += CGFloat(inputDimensions[0]) + 5.0
            }
            else {
                //  Get the size of the output data for the flow
                let outputDimensions = getDisplayDimensions(forDimensions: document.flows[input.index].currentOutputSize)
                
                //  X location is the parents' x location, minus the size of the parent, the connectors, and the output block
                flowLocations![input.index].x = flowLocations![flowIndex].x -
                                (flowSizes![flowIndex].x + totalWidthsForFlows![flowIndex] * 0.5 + CGFloat(outputDimensions[2]))
                
                //  Center the flow in the width allocated for it
                zLocation += totalWidthsForFlows![input.index] * 0.5
                flowLocations![input.index].y = zLocation
                zLocation += totalWidthsForFlows![input.index] * 0.5
                
                //  Recurse
                getRelativeLocation(flowIndex : input.index, document : document)
                
                //  Skip the inter-flow margin
                zLocation += 5.0
            }
        }
    }

    
    func animateColor(from: NSColor, to: NSColor, percentage: CGFloat) -> NSColor
    {
        let fromComponents = from.cgColor.components!
        let toComponents = to.cgColor.components!
        let color = NSColor(red: fromComponents[0] + (toComponents[0] - fromComponents[0]) * percentage,
                            green: fromComponents[1] + (toComponents[1] - fromComponents[1]) * percentage,
                            blue: fromComponents[2] + (toComponents[2] - fromComponents[2]) * percentage,
                            alpha: fromComponents[3] + (toComponents[3] - fromComponents[3]) * percentage)
        return color
    }
    
    func addInputPadding(layer: Layer, xPos: CGFloat, inputDimensions: [Int], zOffset : CGFloat, xScale : CGFloat)
    {
        let padding = layer.getPaddingSize()
        let opacity : CGFloat = 0.7
        
        //  Padding on the left
        if (padding.left > 0) {
            let padGeometry = createBox(width: CGFloat(inputDimensions[2] * inputDimensions[3]), height: CGFloat(inputDimensions[1]), length: CGFloat(padding.left), xScale : xScale)
            if let material = createFeatureTexture(color: NSColor.yellow) {
                padGeometry.materials = [material]
            }
            else {
                padGeometry.firstMaterial!.diffuse.contents = NSColor.yellow
            }
            let padNode = SCNNode(geometry: padGeometry)
            padNode.opacity = opacity
            padNode.position = SCNVector3Make(xPos, 0.0, CGFloat(inputDimensions[1] + padding.left) * 0.5 + zOffset)
            self.rootNode.addChildNode(padNode)
            addedNodes.append(padNode)
        }
        
        //  Padding on the right
        if (padding.right > 0) {
            let padGeometry = createBox(width: CGFloat(inputDimensions[2] * inputDimensions[3]), height: CGFloat(inputDimensions[1]), length: CGFloat(padding.right), xScale : xScale)
            if let material = createFeatureTexture(color: NSColor.yellow) {
                padGeometry.materials = [material]
            }
            else {
                padGeometry.firstMaterial!.diffuse.contents = NSColor.yellow
            }
            let padNode = SCNNode(geometry: padGeometry)
            padNode.opacity = opacity
            padNode.position = SCNVector3Make(xPos, 0.0, -CGFloat(inputDimensions[1] + padding.right) * 0.5 + zOffset)
            self.rootNode.addChildNode(padNode)
            addedNodes.append(padNode)
        }
        
        //  Padding on the top
        if (padding.top > 0) {
            let padGeometry = createBox(width: CGFloat(inputDimensions[2] * inputDimensions[3]), height: CGFloat(padding.top), length: CGFloat(inputDimensions[0]), xScale : xScale)
            if let material = createFeatureTexture(color: NSColor.yellow) {
                padGeometry.materials = [material]
            }
            else {
                padGeometry.firstMaterial!.diffuse.contents = NSColor.yellow
            }
            let padNode = SCNNode(geometry: padGeometry)
            padNode.opacity = opacity
            padNode.position = SCNVector3Make(xPos, CGFloat(inputDimensions[0] + padding.top) * 0.5, zOffset)
            self.rootNode.addChildNode(padNode)
            addedNodes.append(padNode)
        }
        
        //  Padding on the bottom
        if (padding.bottom > 0) {
            let padGeometry = createBox(width: CGFloat(inputDimensions[2] * inputDimensions[3]), height: CGFloat(padding.bottom), length: CGFloat(inputDimensions[0]), xScale : xScale)
            if let material = createFeatureTexture(color: NSColor.yellow) {
                padGeometry.materials = [material]
            }
            else {
                padGeometry.firstMaterial!.diffuse.contents = NSColor.yellow
            }
            let padNode = SCNNode(geometry: padGeometry)
            padNode.opacity = opacity
            padNode.position = SCNVector3Make(xPos, -CGFloat(inputDimensions[0] + padding.bottom) * 0.5,  zOffset)
            self.rootNode.addChildNode(padNode)
            addedNodes.append(padNode)
        }
        
        //  Padding on the top-left
        if (padding.left > 0 && padding.top > 0) {
            let padGeometry = createBox(width: CGFloat(inputDimensions[2] * inputDimensions[3]), height: CGFloat(padding.top), length: CGFloat(padding.left), xScale : xScale)
            if let material = createFeatureTexture(color: NSColor.yellow) {
                padGeometry.materials = [material]
            }
            else {
                padGeometry.firstMaterial!.diffuse.contents = NSColor.yellow
            }
            let padNode = SCNNode(geometry: padGeometry)
            padNode.opacity = opacity
            padNode.position = SCNVector3Make(xPos, CGFloat(inputDimensions[0] + padding.top) * 0.5, CGFloat(inputDimensions[1] + padding.left) * 0.5 + zOffset)
            self.rootNode.addChildNode(padNode)
            addedNodes.append(padNode)
        }
        
        //  Padding on the top-right
        if (padding.right > 0 && padding.top > 0) {
            let padGeometry = createBox(width: CGFloat(inputDimensions[2] * inputDimensions[3]), height: CGFloat(padding.top), length: CGFloat(padding.right), xScale : xScale)
            if let material = createFeatureTexture(color: NSColor.yellow) {
                padGeometry.materials = [material]
            }
            else {
                padGeometry.firstMaterial!.diffuse.contents = NSColor.yellow
            }
            let padNode = SCNNode(geometry: padGeometry)
            padNode.opacity = opacity
            padNode.position = SCNVector3Make(xPos, CGFloat(inputDimensions[0] + padding.top) * 0.5, -CGFloat(inputDimensions[1] + padding.right) * 0.5 + zOffset)
            self.rootNode.addChildNode(padNode)
            addedNodes.append(padNode)
        }
        
        //  Padding on the bottom-left
        if (padding.left > 0 && padding.bottom > 0) {
            let padGeometry = createBox(width: CGFloat(inputDimensions[2] * inputDimensions[3]), height: CGFloat(padding.bottom), length: CGFloat(padding.left), xScale : xScale)
            if let material = createFeatureTexture(color: NSColor.yellow) {
                padGeometry.materials = [material]
            }
            else {
                padGeometry.firstMaterial!.diffuse.contents = NSColor.yellow
            }
            let padNode = SCNNode(geometry: padGeometry)
            padNode.opacity = opacity
            padNode.position = SCNVector3Make(xPos, -CGFloat(inputDimensions[0] + padding.bottom) * 0.5, CGFloat(inputDimensions[1] + padding.left) * 0.5 + zOffset)
            self.rootNode.addChildNode(padNode)
            addedNodes.append(padNode)
        }
        
        //  Padding on the bottom-right
        if (padding.right > 0 && padding.bottom > 0) {
            let padGeometry = createBox(width: CGFloat(inputDimensions[2] * inputDimensions[3]), height: CGFloat(padding.bottom), length: CGFloat(padding.right), xScale : xScale)
            if let material = createFeatureTexture(color: NSColor.yellow) {
                padGeometry.materials = [material]
            }
            else {
                padGeometry.firstMaterial!.diffuse.contents = NSColor.yellow
            }
            let padNode = SCNNode(geometry: padGeometry)
            padNode.opacity = opacity
            padNode.position = SCNVector3Make(xPos, -CGFloat(inputDimensions[0] + padding.bottom) * 0.5, -CGFloat(inputDimensions[1] + padding.right) * 0.5 + zOffset)
            self.rootNode.addChildNode(padNode)
            addedNodes.append(padNode)
        }
    }
    
    func createFeatureTexture(color: NSColor) -> SCNMaterial?
    {
        //  Get the shading image
        let shadingImage = NSImage(named: "ElementTexture")
        if (shadingImage == nil) { return nil }
        
        //  Create a draw image of the same size
        let drawImage = NSImage(size: shadingImage!.size)
        
        //  Draw the background color
        drawImage.lockFocus()
        color.set()
        let rect = NSRect(x: 0, y: 0, width: drawImage.size.width, height: drawImage.size.height)
        rect.fill()
        shadingImage!.draw(in: rect, from: rect, operation: .overlay, fraction: 1.0)
        drawImage.unlockFocus()
        
        let elementTextureMaterial = SCNMaterial()
        elementTextureMaterial.diffuse.contents = drawImage
        elementTextureMaterial.diffuse.wrapS = .repeat
        elementTextureMaterial.diffuse.wrapT = .repeat
        
        return elementTextureMaterial
    }
    
    
    func createBox(width: CGFloat, height: CGFloat, length: CGFloat, xScale: CGFloat) -> SCNGeometry
    {
        let coordinates  : [SCNVector3] = [
            SCNVector3(x: -width/2 * xScale, y: -height/2, z:  length/2),        //  Front
            SCNVector3(x:  width/2 * xScale, y: -height/2, z:  length/2),
            SCNVector3(x:  width/2 * xScale, y:  height/2, z:  length/2),
            SCNVector3(x: -width/2 * xScale, y:  height/2, z:  length/2),
            
            SCNVector3(x:  width/2 * xScale, y: -height/2, z:  length/2),        //  Right
            SCNVector3(x:  width/2 * xScale, y: -height/2, z: -length/2),
            SCNVector3(x:  width/2 * xScale, y:  height/2, z: -length/2),
            SCNVector3(x:  width/2 * xScale, y:  height/2, z:  length/2),
            
            SCNVector3(x:  width/2 * xScale, y: -height/2, z: -length/2),        //  Back
            SCNVector3(x: -width/2 * xScale, y: -height/2, z: -length/2),
            SCNVector3(x: -width/2 * xScale, y:  height/2, z: -length/2),
            SCNVector3(x:  width/2 * xScale, y:  height/2, z: -length/2),
            
            SCNVector3(x: -width/2 * xScale, y: -height/2, z: -length/2),        //  Left
            SCNVector3(x: -width/2 * xScale, y: -height/2, z:  length/2),
            SCNVector3(x: -width/2 * xScale, y:  height/2, z:  length/2),
            SCNVector3(x: -width/2 * xScale, y:  height/2, z: -length/2),
            
            SCNVector3(x: -width/2 * xScale, y:  height/2, z:  length/2),        //  Top
            SCNVector3(x:  width/2 * xScale, y:  height/2, z:  length/2),
            SCNVector3(x:  width/2 * xScale, y:  height/2, z: -length/2),
            SCNVector3(x: -width/2 * xScale, y:  height/2, z: -length/2),
            
            SCNVector3(x: -width/2 * xScale, y: -height/2, z: -length/2),        //  Bottom
            SCNVector3(x:  width/2 * xScale, y: -height/2, z: -length/2),
            SCNVector3(x:  width/2 * xScale, y: -height/2, z:  length/2),
            SCNVector3(x: -width/2 * xScale, y: -height/2, z:  length/2)
        ]
        
        let normals  : [SCNVector3] = [
            SCNVector3(x:  0.0, y:  0.0, z:  1.0),        //  Front
            SCNVector3(x:  0.0, y:  0.0, z:  1.0),
            SCNVector3(x:  0.0, y:  0.0, z:  1.0),
            SCNVector3(x:  0.0, y:  0.0, z:  1.0),
            
            SCNVector3(x:  1.0, y:  0.0, z:  0.0),        //  Right
            SCNVector3(x:  1.0, y:  0.0, z:  0.0),
            SCNVector3(x:  1.0, y:  0.0, z:  0.0),
            SCNVector3(x:  1.0, y:  0.0, z:  0.0),

            SCNVector3(x:  0.0, y:  0.0, z: -1.0),        //  Back
            SCNVector3(x:  0.0, y:  0.0, z: -1.0),
            SCNVector3(x:  0.0, y:  0.0, z: -1.0),
            SCNVector3(x:  0.0, y:  0.0, z: -1.0),

            SCNVector3(x: -1.0, y:  0.0, z:  0.0),        //  Left
            SCNVector3(x: -1.0, y:  0.0, z:  0.0),
            SCNVector3(x: -1.0, y:  0.0, z:  0.0),
            SCNVector3(x: -1.0, y:  0.0, z:  0.0),

            SCNVector3(x:  0.0, y:  1.0, z:  0.0),        //  Top
            SCNVector3(x:  0.0, y:  1.0, z:  0.0),
            SCNVector3(x:  0.0, y:  1.0, z:  0.0),
            SCNVector3(x:  0.0, y:  1.0, z:  0.0),

            SCNVector3(x:  0.0, y: -1.0, z:  0.0),        //  Bottom
            SCNVector3(x:  0.0, y: -1.0, z:  0.0),
            SCNVector3(x:  0.0, y: -1.0, z:  0.0),
            SCNVector3(x:  0.0, y: -1.0, z:  0.0)
        ]
        
        let textureCoordinates  : [CGPoint] = [
            CGPoint(x: 0.0, y: 0.0),        //  Front
            CGPoint(x: width, y: 0.0),
            CGPoint(x: width, y: height),
            CGPoint(x: 0.0, y: height),
            
            CGPoint(x: 0.0, y: 0.0),        //  Right
            CGPoint(x: length, y: 0.0),
            CGPoint(x: length, y: height),
            CGPoint(x: 0.0, y: height),
            
            CGPoint(x: 0.0, y: 0.0),        //  Back
            CGPoint(x: width, y: 0.0),
            CGPoint(x: width, y: height),
            CGPoint(x: 0.0, y: height),
            
            CGPoint(x: 0.0, y: 0.0),        //  Left
            CGPoint(x: length, y: 0.0),
            CGPoint(x: length, y: height),
            CGPoint(x: 0.0, y: height),
            
            CGPoint(x: 0.0, y: 0.0),        //  Top
            CGPoint(x: width, y: 0.0),
            CGPoint(x: width, y: length),
            CGPoint(x: 0.0, y: length),
            
            CGPoint(x: 0.0, y: 0.0),        //  Bottom
            CGPoint(x: width, y: 0.0),
            CGPoint(x: width, y: length),
            CGPoint(x: 0.0, y: length)
        ]

        
        //  Create the geometry source
        let vertexSource = SCNGeometrySource(vertices: coordinates)
        let normalSource = SCNGeometrySource(normals: normals)
        let textCoordSource = SCNGeometrySource(textureCoordinates: textureCoordinates)

        let indices: [Int32] = [
            0,  1,  2,     0,  2,  3,            //  Front
            4,  5,  6,     4,  6,  7,            //  Right
            8,  9, 10,     8, 10, 11,            //  Back
            12, 13, 14,    12, 14, 15,             //  Left
            16, 17, 18,    16, 18, 19,             //  Top
            20, 21, 22,    20, 22, 23             //  Bottom
        ]
        
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        
        let geometry = SCNGeometry(sources: [vertexSource, normalSource, textCoordSource], elements: [element])
        
        return geometry

    }
    
    func createFrustum(bottomWidth: CGFloat, bottomHeight: CGFloat, length: CGFloat, topWidth: CGFloat, topHeight: CGFloat) -> SCNGeometry
    {
        let coordinates  : [SCNVector3] = [
            SCNVector3(x: -bottomWidth/2, y: -bottomHeight/2, z: -length/2),        //  Front
            SCNVector3(x:  bottomWidth/2, y: -bottomHeight/2, z: -length/2),
            SCNVector3(x:  topWidth/2,    y: -topHeight/2,    z:  length/2),
            SCNVector3(x: -topWidth/2,    y: -topHeight/2,    z:  length/2),
            SCNVector3(x:  bottomWidth/2, y: -bottomHeight/2, z: -length/2),        //  Right
            SCNVector3(x:  bottomWidth/2, y:  bottomHeight/2, z: -length/2),
            SCNVector3(x:  topWidth/2,    y:  topHeight/2,    z:  length/2),
            SCNVector3(x:  topWidth/2,    y: -topHeight/2,    z:  length/2),
            SCNVector3(x:  bottomWidth/2, y:  bottomHeight/2, z: -length/2),        //  Back
            SCNVector3(x: -bottomWidth/2, y:  bottomHeight/2, z: -length/2),
            SCNVector3(x: -topWidth/2,    y:  topHeight/2,    z:  length/2),
            SCNVector3(x:  topWidth/2,    y:  topHeight/2,    z:  length/2),
            SCNVector3(x: -bottomWidth/2, y:  bottomHeight/2, z: -length/2),        //  Left
            SCNVector3(x: -bottomWidth/2, y: -bottomHeight/2, z: -length/2),
            SCNVector3(x: -topWidth/2,    y: -topHeight/2,    z:  length/2),
            SCNVector3(x: -topWidth/2,    y:  topHeight/2,    z:  length/2)
        ]
        
        let bottomX = (bottomWidth - topWidth) * 0.5
        let normalizerX = 1.0 / sqrt((length * length) + (bottomX * bottomX))
        let bottomY = (bottomHeight - topHeight) * 0.5
        let normalizerY = 1.0 / sqrt((length * length) + (bottomY * bottomY))
        
        let normals  : [SCNVector3] = [
            SCNVector3(x:                     0,    y:  length * normalizerY,    z:  bottomY * normalizerY),        //  Front
            SCNVector3(x:                     0,    y:  length * normalizerY,    z:  bottomY * normalizerY),
            SCNVector3(x:                     0,    y:  length * normalizerY,    z:  bottomY * normalizerY),
            SCNVector3(x:                     0,    y:  length * normalizerY,    z:  bottomY * normalizerY),
            SCNVector3(x:  length * normalizerX,    y:                     0,    z:  bottomX * normalizerX),        //  Right
            SCNVector3(x:  length * normalizerX,    y:                     0,    z:  bottomX * normalizerX),
            SCNVector3(x:  length * normalizerX,    y:                     0,    z:  bottomX * normalizerX),
            SCNVector3(x:  length * normalizerX,    y:                     0,    z:  bottomX * normalizerX),
            SCNVector3(x:                     0,    y:  length * normalizerY,    z:  bottomY * normalizerY),        //  Back
            SCNVector3(x:                     0,    y:  length * normalizerY,    z:  bottomY * normalizerY),
            SCNVector3(x:                     0,    y:  length * normalizerY,    z:  bottomY * normalizerY),
            SCNVector3(x:                     0,    y:  length * normalizerY,    z:  bottomY * normalizerY),
            SCNVector3(x: -length * normalizerX,    y:                     0,    z:  bottomX * normalizerX),        //  Left
            SCNVector3(x: -length * normalizerX,    y:                     0,    z:  bottomX * normalizerX),
            SCNVector3(x: -length * normalizerX,    y:                     0,    z:  bottomX * normalizerX),
            SCNVector3(x: -length * normalizerX,    y:                     0,    z:  bottomX * normalizerX)
        ]
        
        //  Create the geometry source
        let vertexSource = SCNGeometrySource(vertices: coordinates)
        let normalSource = SCNGeometrySource(normals: normals)
        
        let indices: [Int32] = [
            0,  1,  2,     0,  2,  3,            //  Front
            4,  5,  6,     4,  6,  7,            //  Right
            8,  9, 10,     8, 10, 11,            //  Back
           12, 13, 14,    12, 14, 15             //  Left
        ]
        
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)

        let geometry = SCNGeometry(sources: [vertexSource, normalSource], elements: [element])
        
        return geometry
    }
    
    func createSkewedSquareTube(width: CGFloat, height: CGFloat, length: CGFloat, rightHeightOffset: CGFloat, rightLengthOffset: CGFloat) -> SCNGeometry
    {
        let coordinates  : [SCNVector3] = [
            SCNVector3(x: -width/2, y: -height/2,                     z:  length/2),        //  Front
            SCNVector3(x:  width/2, y: -height/2 + rightHeightOffset, z:  length/2 + rightLengthOffset),
            SCNVector3(x:  width/2, y:  height/2 + rightHeightOffset, z:  length/2 + rightLengthOffset),
            SCNVector3(x: -width/2, y:  height/2,                     z:  length/2),
            
            SCNVector3(x: -width/2, y:  height/2,                     z:  length/2),        //  Top
            SCNVector3(x:  width/2, y:  height/2 + rightHeightOffset, z:  length/2 + rightLengthOffset),
            SCNVector3(x:  width/2, y:  height/2 + rightHeightOffset, z: -length/2 + rightLengthOffset),
            SCNVector3(x: -width/2, y:  height/2,                     z: -length/2),
            
            SCNVector3(x: -width/2, y:  height/2,                     z: -length/2),        //  Back
            SCNVector3(x:  width/2, y:  height/2 + rightHeightOffset, z: -length/2 + rightLengthOffset),
            SCNVector3(x:  width/2, y: -height/2 + rightHeightOffset, z: -length/2 + rightLengthOffset),
            SCNVector3(x: -width/2, y: -height/2,                     z: -length/2),
            
            SCNVector3(x: -width/2, y: -height/2,                     z: -length/2),        //  Bottom
            SCNVector3(x:  width/2, y: -height/2 + rightHeightOffset, z: -length/2 + rightLengthOffset),
            SCNVector3(x:  width/2, y: -height/2 + rightHeightOffset, z:  length/2 + rightLengthOffset),
            SCNVector3(x: -width/2, y: -height/2,                     z:  length/2)
        ]
        
        let frontBackNormalizer = sqrt((rightLengthOffset * rightLengthOffset) + (width * width))
        let topBottomNormalizer = sqrt((rightHeightOffset * rightHeightOffset) + (width * width))
        let frontBackX = rightLengthOffset / frontBackNormalizer
        let frontBackZ = width / frontBackNormalizer
        let topBottomX = rightHeightOffset / topBottomNormalizer
        let topBottomY = width / topBottomNormalizer

        let normals  : [SCNVector3] = [
            SCNVector3(x: -frontBackX,    y:  0,    z:  frontBackZ),        //  Front
            SCNVector3(x: -frontBackX,    y:  0,    z:  frontBackZ),
            SCNVector3(x: -frontBackX,    y:  0,    z:  frontBackZ),
            SCNVector3(x: -frontBackX,    y:  0,    z:  frontBackZ),
            
            SCNVector3(x: -topBottomX,    y:  topBottomY,    z:  0),        //  Top
            SCNVector3(x: -topBottomX,    y:  topBottomY,    z:  0),
            SCNVector3(x: -topBottomX,    y:  topBottomY,    z:  0),
            SCNVector3(x: -topBottomX,    y:  topBottomY,    z:  0),
            
            SCNVector3(x:  frontBackX,    y:  0,    z: -frontBackZ),        //  Back
            SCNVector3(x:  frontBackX,    y:  0,    z: -frontBackZ),
            SCNVector3(x:  frontBackX,    y:  0,    z: -frontBackZ),
            SCNVector3(x:  frontBackX,    y:  0,    z: -frontBackZ),
            
            SCNVector3(x:  topBottomX,    y: -topBottomY,    z:  0),        //  Bottom
            SCNVector3(x:  topBottomX,    y: -topBottomY,    z:  0),
            SCNVector3(x:  topBottomX,    y: -topBottomY,    z:  0),
            SCNVector3(x:  topBottomX,    y: -topBottomY,    z:  0)
        ]

        //  Create the geometry source
        let vertexSource = SCNGeometrySource(vertices: coordinates)
        let normalSource = SCNGeometrySource(normals: normals)

        let indices: [Int32] = [
            0,  1,  2,     0,  2,  3,            //  Front
            4,  5,  6,     4,  6,  7,            //  Top
            8,  9, 10,     8, 10, 11,            //  Back
           12, 13, 14,    12, 14, 15             //  Bottom
        ]

        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)

        let geometry = SCNGeometry(sources: [vertexSource, normalSource], elements: [element])

        return geometry
    }

    func getDisplayDimensions(forDimensions: [Int]) -> [Int]
    {
        //  If not a 1x1xN array, return as is, with channels and time combined
        if (forDimensions[0] != 1 || forDimensions[1] != 1 || !use_XxY_for_1x1xN) {
            return [forDimensions[0], forDimensions[1], forDimensions[2] * forDimensions[3]]
        }
        
        //  Convert the long dimension to an array size
        let size = Network3DScene.getXYforN(forDimensions[2] * forDimensions[3])
        
        //  Return a plane of that size
        return [size.X, size.Y, 1]
    }

    class func getXYforN(_ N : Int) -> (X: Int, Y: Int)
    {
        //  Get the factors of N
        var factors : [Int] = []
        let lastCheck = Int(sqrt(Double(N)))
        var current = N
        while ((current % 2) == 0) {
            factors.append(2)
            current /= 2
        }
        for divisor in stride(from: 3, to: lastCheck, by: 2) {
            while ((current % divisor) == 0) {
                factors.append(divisor)
                current /= divisor
            }
        }
        if (current > 2) { factors.append(current) }
        
        //  If only one factor, return it
        if (factors.count < 2) { return (X: N, Y: 1) }
        
        //  Sort the factors
        factors.sort()
        
        //  Start with the two biggest factors
        var x = factors.last!
        factors.removeLast()
        var y = factors.last!
        factors.removeLast()
        while (factors.count > 0) {
            let factor = factors.last!
            if (x < y) {
                x *= factor
            }
            else {
                y *= factor
            }
            factors.removeLast()
        }
        
        //  Make x the bigger of the two
        if (x < y) {
            let temp = x
            x = y
            y = temp
        }

        return (X: x, Y: y)
    }
}
