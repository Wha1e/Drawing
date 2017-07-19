//
//  ViewController.swift
//  Drawing
//
//  Created by Tristan Struthers on 7/13/17.
//  Copyright © 2017 Tristan Struthers. All rights reserved.
//

import ARKit
import Foundation
import UIKit
import SceneKit
import GLKit

class ViewController: UIViewController, ARSCNViewDelegate {
    
    // MARK: Class Properties
    var rootNode: SCNNode?
    var sessTool: Tool?
    var userIsDrawing = false
    var userIsMovingStructure = false
    var bufferNode: SCNNode?
    var selectionHolderNode: SCNNode?
    var newPointBuffer: [SCNNode]?
    var worldUp: SCNVector4 {
        let wUp = rootNode!.worldUp
        let upVec = SCNVector4.init(wUp.x, wUp.y, wUp.z, 1.0)
        return upVec
    }
    
    // MARK: Setup and Configuration
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupScene()
        setupTool()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    var configuration = ARWorldTrackingSessionConfiguration()
    func setupScene() {
        // Configure and setup the scene view
        configuration.planeDetection = .horizontal
        sceneView.delegate = self
        
        sceneView.antialiasingMode = .multisampling4X
        sceneView.automaticallyUpdatesLighting = true
        sceneView.preferredFramesPerSecond = 60
        sceneView.contentScaleFactor = 1.3
        rootNode = sceneView.scene.rootNode
        
        sceneView.session.run(configuration)
    }
    
    func setupTool() {
        sessTool = Tool()
        sessTool!.rootNode = self.rootNode!
        if sessTool!.toolNode == nil {
            sessTool!.toolNode = SCNNode(geometry: SCNSphere(radius: (sessTool?.size)!))
            sessTool!.toolNode?.geometry?.firstMaterial?.diffuse.contents = UIColor.white
            sessTool!.toolNode?.rotation = worldUp
            rootNode!.addChildNode(sessTool!.toolNode!)
        }
    }
    
    // MARK: Outlets
    
    @IBOutlet weak var sceneView: ARSCNView! {
        didSet {
            let holdRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(reactToLongPress(byReactingTo:)))
            holdRecognizer.minimumPressDuration = CFTimeInterval(0.1)
            sceneView.addGestureRecognizer(holdRecognizer)
            
            let singleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(reactToTap(byReactingTo:)))
            sceneView.addGestureRecognizer(singleTapRecognizer)
            
            let leftSwipeRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(reactToSwipe(byReactingTo:)))
            leftSwipeRecognizer.direction = .left
            sceneView.addGestureRecognizer(leftSwipeRecognizer)
            
            let rightSwipeRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(reactToSwipe(byReactingTo:)))
            rightSwipeRecognizer.direction = .right
            sceneView.addGestureRecognizer(rightSwipeRecognizer)
            
            let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(reactToPinch(byReactingTo:)))
            sceneView.addGestureRecognizer(pinchRecognizer)
        }
    }
    
    @IBAction func deleteButton(_ sender: UIButton) {
            for selectedNode in self.sessTool!.selection {
                sessTool!.updateSelection(withSelectedNode: selectedNode)
                selectedNode.removeFromParentNode()
            }
    }
    
    
    // MARK: Gesture Handlers
    
    @objc func reactToLongPress(byReactingTo holdRecognizer: UILongPressGestureRecognizer) {
        // Check tool type and react accordingly here
        switch (sessTool?.currentMode)! {
        case .Pen:
            switch holdRecognizer.state {
            case .began:
                userIsDrawing = true
            case .ended:
                userIsDrawing = false
            default: break
            }
            
        case .Manipulator:
            switch holdRecognizer.state {
            case .began:
                userIsMovingStructure = true
            case .ended:
                userIsMovingStructure = false
            default: break
            }
        }
    }
    
    @objc func reactToTap(byReactingTo singleTapRecognizer: UITapGestureRecognizer) {
        switch (sessTool?.currentMode)! {
        case .Manipulator:
            let resultPoints = sceneView.hitTest(singleTapRecognizer.location(in: sceneView), options: nil)
            if resultPoints.count > 0 {
                let resultNode = resultPoints[0].node
                if resultNode.isEqual(sessTool!.toolNode) {
                    break
                }
                if let parentNode = resultNode.parent {
                    sessTool!.updateSelection(withSelectedNode: parentNode)
                }
            }
        case .Pen:
            break
        }
        
    }
    
    @objc func reactToSwipe(byReactingTo swipeRecognizer: UISwipeGestureRecognizer) {
        sessTool!.swipe(swipeRecognizer)
    }
    
    @objc func reactToPinch(byReactingTo pinchRecognizer: UIPinchGestureRecognizer) {
        // Check tool type and react accordingly here
        switch (sessTool?.currentMode)! {
        case .Pen:
            switch pinchRecognizer.state {
            case .began, .changed:
                sessTool?.size *= pinchRecognizer.scale
                pinchRecognizer.scale = 1
            default: break
            }
        case .Manipulator:
            switch pinchRecognizer.state {
            case .began, .changed:
                for parentNode in sessTool!.selection {
                    parentNode.scale.scaleBy(Float(pinchRecognizer.scale))
                    pinchRecognizer.scale = 1
                }
            default: break
            }
        }
    }

    
    // MARK: Public Class Methods
    
    func updateTool() {
        positionNode((sessTool?.toolNode!)!, atDist: (sessTool?.distanceFromCamera)!)
    }

    private func positionNode(_ node: SCNNode, atDist dist: Float) {
            node.transform = (sceneView.pointOfView?.transform)!
            var pointerVector = SCNVector3(-1 * node.transform.m31, -1 * node.transform.m32, -1 * node.transform.m33)
            pointerVector.scaleBy(dist)
            node.position = node.position + pointerVector
    }
    
    func updateDraw(){
        if userIsDrawing {
            if bufferNode == nil {
                bufferNode = SCNNode()
                rootNode?.addChildNode(bufferNode!)
                newPointBuffer = []
            } else {
                
                let newNode = (SCNNode(geometry: SCNSphere(radius: (sessTool?.size)!)))
                newNode.convertTransform(newNode.transform, from: rootNode!)
                positionNode(newNode, atDist: sessTool!.distanceFromCamera)
                newPointBuffer!.append(newNode)
                rootNode!.addChildNode(newNode)
            }
        } else {
            if bufferNode != nil {
                let newParent = SCNNode()
                rootNode!.addChildNode(newParent)
                let bestCentroid = calculateGlobalCentroid(newPointBuffer!)
                newParent.position = bestCentroid
                newParent.rotation = (sessTool!.toolNode?.rotation)!
                newParent.geometry = SCNSphere(radius: 0.03)
                newParent.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
                
                rootNode!.addChildNode(newParent)
                DispatchQueue.main.async {
                    while self.newPointBuffer!.count > 0 {
                        let newNode = self.newPointBuffer!.removeFirst()
                        let newNodeCopy = newNode.clone()
                        let origTrans = newNode.worldTransform
                        newParent.addChildNode(newNodeCopy)
                        newNode.removeFromParentNode()
                        newNodeCopy.setWorldTransform(origTrans)
                    }
                    self.bufferNode = nil
                }
            }
        }
    }
    
    func updateMove() {
        if userIsMovingStructure {
            if selectionHolderNode == nil {
                selectionHolderNode = SCNNode(geometry: SCNSphere(radius: 0.03))
                selectionHolderNode!.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
                rootNode?.addChildNode(selectionHolderNode!)
                
                let selectionCentroid = calculateGlobalCentroid(Array(sessTool!.selection))
                selectionHolderNode!.position = selectionCentroid
                selectionHolderNode!.rotation = (sessTool!.toolNode?.rotation)!
                
                for parentNode in sessTool!.selection {
                    DispatchQueue.main.async {
                        for childNode in parentNode.childNodes {
                            let origTrans = childNode.worldTransform
                            childNode.removeFromParentNode()
                            self.selectionHolderNode!.addChildNode(childNode)
                            childNode.setWorldTransform(origTrans)
                        }
                        parentNode.removeFromParentNode()
                        self.sessTool!.updateSelection(withSelectedNode: parentNode)
                        self.sessTool!.updateSelection(withSelectedNode: self.selectionHolderNode!)
                    }
                }
            } else {
                selectionHolderNode!.transform = (sessTool!.toolNode?.transform)!
            }
        } else {
            if selectionHolderNode != nil {
                DispatchQueue.main.async {
                    let newNode = SCNNode()
                    newNode.transform = self.selectionHolderNode!.transform
                    for childNode in self.selectionHolderNode!.childNodes {
                        newNode.addChildNode(childNode)
                    }
                    self.rootNode!.replaceChildNode(self.selectionHolderNode!, with: newNode)
                    self.sessTool!.updateSelection(withSelectedNode: self.selectionHolderNode!)
                    self.sessTool!.updateSelection(withSelectedNode: newNode)

                    self.selectionHolderNode!.removeFromParentNode()
                    self.selectionHolderNode = nil
                }
            }
            
        }
    }
    
    // MARK: Private Class Methods
    
    private func calculateGlobalCentroid(_ nodeList: [SCNNode]) -> SCNVector3 {
        var averagePos = SCNVector3()
        for aNode in nodeList {
            let globalTransMat = aNode.worldTransform
            let translVec = SCNVector3.init(globalTransMat.m41, globalTransMat.m42, globalTransMat.m43)
            averagePos = averagePos + translVec
        }
        averagePos.scaleBy(1.0/Float(nodeList.count))
        return averagePos
    }
    
    // MARK: Delegate Methods
    
    func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {
        updateDraw()
        updateMove()
        updateTool()
        
    }
}
