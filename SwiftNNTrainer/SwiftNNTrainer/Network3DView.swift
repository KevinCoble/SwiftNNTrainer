//
//  Network3DView.swift
//  SwiftNNTrainer
//
//  Created by Kevin Coble on 2/25/19.
//  Copyright © 2019 Kevin Coble. All rights reserved.
//

import Cocoa
import SceneKit

class Network3DView: SCNView {
    
    var controller : NetworkViewController?
    
    override func mouseUp(with event: NSEvent)
    {
        //  Get the click location
        let location = convert(event.locationInWindow, to: self)
        
        //  Get the output location
        let xLoc = (location.x - frame.origin.x)
        let yLoc = (location.y - frame.origin.y)

        // layer nodes labeled "Flow\(flowIndex)Layer\(layerIndex)"
        let hitResults = hitTest(CGPoint(x: xLoc, y:yLoc), options: nil)
        if (hitResults.count > 0)  {
            let result = hitResults[0]
            if let name = result.node.name {
                let intIndex = name.index(name.startIndex, offsetBy: 4)
                let subString = name[intIndex...]   //  String without 'Flow'
                if let layerIndex = subString.firstIndex(of: "L") {         //  Find the start of 'Layer'
                    if let flow = Int(subString[..<layerIndex]) {       //  Everything before Layer is the flow integer
                        let layerStart = subString.index(layerIndex, offsetBy: 5)       //  Find the string after 'Layer'
                        if let index = Int(subString[layerStart...]) {      //  Everything after 'Layer' is the layer integer
                            if let controller = controller {
                                controller.selectLayer(inFlow: flow, atIndex: index)
                            }
                        }
                    }
                }
            }
        }
    }
}
