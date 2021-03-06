//
//  AAPLGameViewController.swift
//  SceneKitReel
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/12/9.
//
//
/*
 Copyright (C) 2017 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 Game View Controller declaration.
 */

#if os(iOS)
    import UIKit
    typealias BaseViewController = UIViewController
    typealias SCNVectorFloat = Float
#else
    import Cocoa
    typealias BaseViewController = NSViewController
    typealias SCNVectorFloat = CGFloat
#endif

import GLKit
import SceneKit
import SpriteKit


private let SLIDE_COUNT = 10

private let TEXT_SCALE = 0.75
private let TEXT_Z_SPACING: SCNVectorFloat = 200

private let MAX_FIRE: CGFloat = 25.0
private let MAX_SMOKE: CGFloat = 20.0

// utility function
private func randFloat<F: FloatingPoint>(_ min: F, _ max: F) -> F {
    return min + (max - min) * F(arc4random()) / F(UInt32.max)
}

private let FACTOR = SCNVectorFloat(2.2)

@objc(AAPLGameViewController)
class AAPLGameViewController: BaseViewController, SCNSceneRendererDelegate, SCNPhysicsContactDelegate {
    //steps of the demo
    private var _introductionStep: Int = 0
    private var _step: Int = 0
    
    //scene
    private var _scene: SCNScene!
    
    // save spot light transform
    private var _originalSpotTransform: SCNMatrix4 = SCNMatrix4()
    
    //references to nodes for manipulation
    private var _cameraHandle: SCNNode!
    private var _cameraOrientation: SCNNode!
    private var _cameraNode: SCNNode!
    private var _spotLightParentNode: SCNNode!
    private var _spotLightNode: SCNNode!
    private var _ambientLightNode: SCNNode!
    private var _floorNode: SCNNode!
    private var _sceneKitLogo: SCNNode!
    private var _mainWall: SCNNode!
    private var _invisibleWallForPhysicsSlide: SCNNode!
    
    //ship
    private var _shipNode: SCNNode?
    private var _shipPivot: SCNNode?
    private var _shipHandle: SCNNode?
    private var _introNodeGroup: SCNNode?
    
    //physics slide
    private var _boxes: [SCNNode] = []
    
    //particles slide
    private var _fireTruck: SCNNode?
    private var _collider: SCNNode?
    private var _emitter: SCNNode?
    private var _fireContainer: SCNNode?
    private var _handle: SCNNode!
    private var _fire: SCNParticleSystem!
    private var _smoke: SCNParticleSystem!
    private var _plok: SCNParticleSystem!
    private var _hitFire: Bool = false
    
    //physics fields slide
    private var _fieldEmitter: SCNNode?
    private var _fieldOwner: SCNNode?
    private var _interactiveField: SCNNode?
    
    //SpriteKit integration slide
    private var _torus: SCNNode!
    private var _splashNode: SCNNode!
    
    //shaders slide
    private var _shaderGroupNode: SCNNode?
    private var _shadedNode: SCNNode!
    private var _shaderStage: Int = 0
    
    // shader modifiers
    private var _geomModifier: String!
    private var _surfModifier: String!
    private var _fragModifier: String!
    private var _lightModifier: String!
    
    //camera manipulation
    private var _cameraBaseOrientation: SCNVector3 = SCNVector3()
    private var _initialOffset: CGPoint = CGPoint()
    private var _lastOffset: CGPoint = CGPoint()
    private var _cameraHandleTransforms: [SCNMatrix4] = Array(repeating: SCNMatrix4(), count: SLIDE_COUNT)
    private var _cameraOrientationTransforms: [SCNMatrix4] = Array(repeating: SCNMatrix4(), count: SLIDE_COUNT)
    //private var _timer: DispatchSource?
    private var _timer: DispatchSourceTimer?
    
    
    private var _preventNext: Bool = false
    
    #if os(iOS)
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.setup()
    }
    #else
    override func awakeFromNib() {
        self.setup()
    }
    #endif
    
    //MARK: mark - Setup
    
    func setup() {
        let sceneView = self.view as! SCNView
        
        //redraw forever
        sceneView.isPlaying = true
        sceneView.loops = true
        sceneView.showsStatistics = true
        
        sceneView.backgroundColor = .black
        
        //setup ivars
        _boxes = []
        
        //setup the scene
        self.setupScene()
        
        //present it
        sceneView.scene = _scene
        
        //tweak physics
        sceneView.scene!.physicsWorld.speed = 2.0
        
        //let's be the delegate of the SCNView
        sceneView.delegate = self
        
        //initial point of view
        sceneView.pointOfView = _cameraNode
        
        //setup overlays
        let overlay = AAPLSpriteKitOverlayScene(size: sceneView.bounds.size)
        sceneView.overlaySKScene = overlay
        
        #if os(iOS)
            var gestureRecognizers: [UIGestureRecognizer] = []
            gestureRecognizers += sceneView.gestureRecognizers ?? []
            
            // add a tap gesture recognizer
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
            
            // add a pan gesture recognizer
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:)))
            
            // add a double tap gesture recognizer
            let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleDoubleTap(_:)))
            doubleTapGesture.numberOfTapsRequired = 2
            
            tapGesture.require(toFail: panGesture)
            
            gestureRecognizers.append(doubleTapGesture)
            gestureRecognizers.append(tapGesture)
            gestureRecognizers.append(panGesture)
            
            //register gesture recognizers
            sceneView.gestureRecognizers = gestureRecognizers
        #endif
        
        if _introductionStep == 0 {
            overlay.showLabel("Go!")
        }
    }
    
    private func setupScene() {
        _scene = SCNScene()
        
        self.setupEnvironment()
        self.setupSceneElements()
        self.setupIntroEnvironment()
    }
    
    private func setupEnvironment() {
        // |_   cameraHandle
        //   |_   cameraOrientation
        //     |_   cameraNode
        
        //create a main camera
        _cameraNode = SCNNode()
        _cameraNode.position = SCNVector3Make(0, 0, 120)
        
        //create a node to manipulate the camera orientation
        _cameraHandle = SCNNode()
        _cameraHandle.position = SCNVector3Make(0, 60, 0)
        
        _cameraOrientation = SCNNode()
        
        _scene?.rootNode.addChildNode(_cameraHandle)
        _cameraHandle.addChildNode(_cameraOrientation)
        _cameraOrientation.addChildNode(_cameraNode)
        
        _cameraNode.camera = SCNCamera()
        _cameraNode.camera!.zFar = 800
        #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .phone {
                _cameraNode.camera!.yFov = 55
            } else {
                _cameraNode.camera!.xFov = 75
            }
        #else
            _cameraNode.camera!.xFov = 75
        #endif
        
        _cameraHandleTransforms[0] = _cameraNode.transform
        
        // add an ambient light
        _ambientLightNode = SCNNode()
        _ambientLightNode.light = SCNLight()
        
        _ambientLightNode.light!.type = .ambient
        _ambientLightNode.light!.color = SKColor(white: 0.3, alpha: 1.0)
        
        _scene.rootNode.addChildNode(_ambientLightNode)
        
        
        //add a key light to the scene
        _spotLightParentNode = SCNNode()
        _spotLightParentNode.position = SCNVector3Make(0, 90, 20)
        
        _spotLightNode = SCNNode()
        _spotLightNode.rotation = SCNVector4Make(1,0,0,-.pi/4)
        
        _spotLightNode.light = SCNLight()
        _spotLightNode.light!.type = .spot
        _spotLightNode.light!.color = SKColor(white: 1.0, alpha: 1.0)
        _spotLightNode.light!.castsShadow = true
        _spotLightNode.light!.shadowColor = SKColor(white: 0, alpha: 0.5)
        _spotLightNode.light!.zNear = 30
        _spotLightNode.light!.zFar = 800
        _spotLightNode.light!.shadowRadius = 1.0
        _spotLightNode.light!.spotInnerAngle = 15
        _spotLightNode.light!.spotOuterAngle = 70
        
        _cameraNode.addChildNode(_spotLightParentNode)
        _spotLightParentNode.addChildNode(_spotLightNode)
        
        //save spotlight transform
        _originalSpotTransform = _spotLightNode.transform
        
        //floor
        let floor = SCNFloor()
        floor.reflectionFalloffEnd = 0
        floor.reflectivity = 0
        
        _floorNode = SCNNode()
        _floorNode.geometry = floor
        _floorNode.geometry!.firstMaterial!.diffuse.contents = "wood.png"
        _floorNode.geometry!.firstMaterial!.locksAmbientWithDiffuse = true
        _floorNode.geometry!.firstMaterial!.diffuse.wrapS = .repeat
        _floorNode.geometry!.firstMaterial!.diffuse.wrapT = .repeat
        _floorNode.geometry!.firstMaterial!.diffuse.mipFilter = .nearest
        _floorNode.geometry!.firstMaterial!.isDoubleSided = false
        
        _floorNode.physicsBody = .static()
        _floorNode.physicsBody!.restitution = 1.0
        
        _scene.rootNode.addChildNode(_floorNode)
    }
    
    private func setupSceneElements() {
        // create the wall geometry
        let wallGeometry = SCNPlane(width: 800, height: 200)
        wallGeometry.firstMaterial!.diffuse.contents = "wallPaper.png"
        wallGeometry.firstMaterial!.diffuse.contentsTransform = SCNMatrix4Mult(SCNMatrix4MakeScale(8, 2, 1), SCNMatrix4MakeRotation(.pi/4, 0, 0, 1))
        wallGeometry.firstMaterial!.diffuse.wrapS = .repeat
        wallGeometry.firstMaterial!.diffuse.wrapT = .repeat
        wallGeometry.firstMaterial!.isDoubleSided = false
        wallGeometry.firstMaterial!.locksAmbientWithDiffuse = true
        
        let wallWithBaseboardNode = SCNNode(geometry: wallGeometry)
        wallWithBaseboardNode.position = SCNVector3Make(200, 100, -20)
        wallWithBaseboardNode.physicsBody = .static()
        wallWithBaseboardNode.physicsBody!.restitution = 1.0
        wallWithBaseboardNode.castsShadow = false
        
        let baseboardNode = SCNNode(geometry: SCNBox(width: 800, height: 8, length: 0.5, chamferRadius: 0))
        baseboardNode.geometry!.firstMaterial!.diffuse.contents = "baseboard.jpg"
        baseboardNode.geometry!.firstMaterial!.diffuse.wrapS = .repeat
        baseboardNode.geometry!.firstMaterial!.isDoubleSided = false
        baseboardNode.geometry!.firstMaterial!.locksAmbientWithDiffuse = true
        baseboardNode.position = SCNVector3Make(0, -wallWithBaseboardNode.position.y + 4, 0.5)
        baseboardNode.castsShadow = false
        baseboardNode.renderingOrder = -3 //render before others
        
        wallWithBaseboardNode.addChildNode(baseboardNode)
        
        //front walls
        _mainWall = wallWithBaseboardNode
        _scene.rootNode.addChildNode(wallWithBaseboardNode)
        _mainWall.renderingOrder = -3 //render before others
        
        //back
        var wallNode = wallWithBaseboardNode.clone()
        wallNode.opacity = 0
        wallNode.physicsBody = .static()
        wallNode.physicsBody!.restitution = 1.0
        wallNode.physicsBody!.categoryBitMask = 1 << 2
        wallNode.castsShadow = false
        if #available(OSX 10.11, iOS 9.0, *) {
            wallNode.physicsBody!.contactTestBitMask = ~0
        }
        
        wallNode.position = SCNVector3Make(0, 100, 0)
        wallNode.rotation = SCNVector4Make(0, 1, 0, .pi)
        _scene.rootNode.addChildNode(wallNode)
        
        //left
        wallNode = wallWithBaseboardNode.clone()
        wallNode.position = SCNVector3Make(-120, 100, 40)
        wallNode.rotation = SCNVector4Make(0, 1, 0, .pi/2)
        _scene.rootNode.addChildNode(wallNode)
        
        
        //right (an invisible wall to keep the bodies in the visible area when zooming in the Physics slide)
        wallNode = wallNode.clone()
        wallNode.opacity = 0
        wallNode.position = SCNVector3Make(120, 100, 40)
        wallNode.rotation = SCNVector4Make(0, 1, 0, -.pi/2)
        _invisibleWallForPhysicsSlide = wallNode
        
        //right (the actual wall on the right)
        wallNode = wallWithBaseboardNode.clone()
        wallNode.physicsBody = nil
        wallNode.position = SCNVector3Make(600, 100, 40)
        wallNode.rotation = SCNVector4Make(0, 1, 0, -.pi/2)
        _scene.rootNode.addChildNode(wallNode)
        
        //top
        wallNode = wallWithBaseboardNode.copy() as! SCNNode
        wallNode.geometry = (wallNode.geometry!.copy() as! SCNGeometry)
        wallNode.geometry!.firstMaterial = SCNMaterial()
        wallNode.opacity = 1
        wallNode.position = SCNVector3Make(200, 200, 0)
        wallNode.scale = SCNVector3Make(1, 10, 1)
        wallNode.rotation = SCNVector4Make(1, 0, 0, .pi/2)
        _scene.rootNode.addChildNode(wallNode)
        
        _mainWall.isHidden = true //hide at first (save some milliseconds)
    }
    
    private func setupIntroEnvironment() {
        _introductionStep = 1
        
        // configure the lighting for the introduction (dark lighting)
        _ambientLightNode.light?.color = SKColor.black
        _spotLightNode.light!.color = SKColor.black
        _spotLightNode.position = SCNVector3Make(50, 90, -50)
        _spotLightNode.eulerAngles = SCNVector3Make(-.pi/2*0.75, .pi/4*0.5, 0)
        
        //put all texts under this node to remove all at once later
        _introNodeGroup = SCNNode()
        
        //Slide 1
        let LOGO_SIZE: CGFloat = 70
        //### let TITLE_SIZE = (TEXT_SCALE*0.45)
        let sceneKitLogo = SCNNode(geometry: SCNPlane(width: LOGO_SIZE, height: LOGO_SIZE))
        sceneKitLogo.geometry!.firstMaterial!.isDoubleSided = true
        sceneKitLogo.geometry!.firstMaterial!.diffuse.contents = "SceneKit.png"
        sceneKitLogo.geometry!.firstMaterial!.emission.contents = "SceneKit.png"
        _sceneKitLogo = sceneKitLogo
        
        _sceneKitLogo.renderingOrder = -1
        _floorNode.renderingOrder = -2
        
        _introNodeGroup?.addChildNode(sceneKitLogo)
        sceneKitLogo.position = SCNVector3Make(200, SCNVectorFloat(LOGO_SIZE)/2, 200)
        
        let position = SCNVector3Make(200, 0, 200)
        
        _cameraNode.position = SCNVector3Make(200, -20, position.z+150)
        _cameraNode.eulerAngles = SCNVector3Make(-.pi/2*0.06, 0, 0)
        
        /* hierarchy
        shipHandle
        |_ shipXTranslate
        |_ shipPivot
        |_ ship */
        let modelScene = SCNScene(named: "ship.dae", inDirectory: "assets.scnassets/models", options: nil)!
        _shipNode = modelScene.rootNode.childNode(withName: "Aircraft", recursively: true)
        
        let shipMesh = _shipNode!.childNode(withName: "mesh", recursively: true)! //###
        //shipMesh.geometry!.firstMaterial!.fresnelExponent = 1.0
        shipMesh.geometry!.firstMaterial!.emission.intensity = 0.5
        shipMesh.renderingOrder = -3
        
        _shipPivot = SCNNode()
        let shipXTranslate = SCNNode()
        _shipHandle = SCNNode()
        
        _shipHandle!.position =  SCNVector3Make(200 - 500, 0, position.z + 30)
        _shipNode!.position = SCNVector3Make(50, 30, 0)
        
        _shipPivot!.addChildNode(_shipNode!)
        shipXTranslate.addChildNode(_shipPivot!)
        _shipHandle!.addChildNode(shipXTranslate)
        _introNodeGroup!.addChildNode(_shipHandle!)
        
        //animate ship
        _shipNode!.removeAllActions()
        _shipNode!.rotation = SCNVector4Make(0, 0, 1, .pi/4*0.5)
        
        //make spotlight relative to the ship
        let newPosition = SCNVector3Make(50, 100, 0)
        let oldTransform = _shipPivot!.convertTransform(SCNMatrix4Identity, from: _spotLightNode)
        
        _spotLightNode.removeFromParentNode()
        _spotLightNode.transform = oldTransform
        _shipPivot!.addChildNode(_spotLightNode)
        
        _spotLightNode.position = newPosition // will animate implicitly
        _spotLightNode.eulerAngles = SCNVector3Make(-.pi/2, 0, 0)
        _spotLightNode.light!.spotOuterAngle = 120
        
        _shipPivot!.eulerAngles = SCNVector3Make(0, .pi/2, 0)
        let action = SCNAction.sequence([.repeatForever(.rotateBy(x: 0, y: .pi, z: 0, duration: 2))])
        _shipPivot!.runAction(action)
        
        let animation = CABasicAnimation(keyPath: "position.x")
        animation.fromValue = -50
        animation.toValue = 50
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        animation.autoreverses = true
        animation.duration = 2
        animation.repeatCount = MAXFLOAT
        animation.timeOffset = -animation.duration*0.5
        shipXTranslate.addAnimation(animation, forKey: nil)
        
        let emitter = _shipNode!.childNode(withName: "emitter", recursively: true)!
        let ps = SCNParticleSystem(named: "reactor.scnp", inDirectory: "assets.scnassets/particles")!
        emitter.addParticleSystem(ps)
        _shipHandle!.position = SCNVector3Make(_shipHandle!.position.x, _shipHandle!.position.y, _shipHandle!.position.z-50)
        
        _scene.rootNode.addChildNode(_introNodeGroup!)
        
        //wait, then fade in light
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 1.0
        SCNTransaction.completionBlock = {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 2.5
            
            self._shipHandle!.position = SCNVector3Make(self._shipHandle!.position.x+500, self._shipHandle!.position.y, self._shipHandle!.position.z)
            
            self._spotLightNode.light!.color = SKColor(white: 1, alpha: 1)
            sceneKitLogo.geometry!.firstMaterial!.emission.intensity = 0.80
            
            SCNTransaction.commit()
        }
        
        _spotLightNode.light!.color = SKColor(white: 0.001, alpha: 1)
        
        SCNTransaction.commit()
    }
    
    //MARK: -
    
    //// the material to use for text
    //- (SCNMaterial *)textMaterial {
    //    static SCNMaterial *material = nil;
    //    if (!material) {
    //        material = [SCNMaterial material];
    //        material.specular.contents   = [SKColor colorWithWhite:0.6 alpha:1];
    //        material.reflective.contents = @"color_envmap.png";
    //        material.shininess           = 0.1;
    //    }
    //    return material;
    //}
    
    // switch to the next introduction step
    private func nextIntroductionStep() {
        _introductionStep += 1
        
        //show wall
        _mainWall.isHidden = false
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 1.0
        SCNTransaction.completionBlock = {
            
            if self._introductionStep == 0 {
                //We did finish introduction step
                
                self._shipHandle?.removeFromParentNode()
                self._shipHandle = nil
                self._shipPivot = nil
                self._shipNode = nil
                
                self._floorNode.renderingOrder = 0
                
                //We did finish the whole introduction
                self._introNodeGroup?.removeFromParentNode()
                self._introNodeGroup = nil
                self.next()
            }
        }
        
        if _introductionStep == 2 {
            _sceneKitLogo.renderingOrder = 0
            
            //restore spot light config
            _spotLightNode.light!.spotOuterAngle = 70
            let oldTransform = _spotLightParentNode.convertTransform(SCNMatrix4Identity, from: _spotLightNode)
            _spotLightNode.removeFromParentNode()
            _spotLightNode.transform = oldTransform
            
            _spotLightParentNode.addChildNode(_spotLightNode)
            
            _cameraNode.position = SCNVector3Make(_cameraNode.position.x, _cameraNode.position.y, _cameraNode.position.z-TEXT_Z_SPACING)
            
            _spotLightNode.transform = _originalSpotTransform
            _ambientLightNode.light!.color = SKColor(white: 0.3, alpha: 1.0)
            _cameraNode.position = SCNVector3Make(0, 0, 120)
            _cameraNode.eulerAngles = SCNVector3Make(0, 0, 0)
            
            _introductionStep = 0 //introduction is over
        } else {
            _cameraNode.position = SCNVector3Make(_cameraNode.position.x, _cameraNode.position.y, _cameraNode.position.z-TEXT_Z_SPACING)
        }
        
        SCNTransaction.commit()
    }
    
    //restore the default camera orientation and position
    private func restoreCameraAngle() {
        //reset drag offset
        _initialOffset = CGPoint(x: 0, y: 0)
        _lastOffset = _initialOffset
        
        //restore default camera
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.5
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
        _cameraHandle.eulerAngles = SCNVector3Make(0, 0, 0)
        SCNTransaction.commit()
    }
    
    // tilt the camera based on an offset
    func tiltCameraWithOffset(_ _offset: CGPoint) {
        guard _introductionStep == 0 else {
            return
        }
        
        var offset = _offset
        offset.x += _initialOffset.x
        offset.y += _initialOffset.y
        
        var tr = CGPoint()
        tr.x = offset.x - _lastOffset.x
        tr.y = offset.y - _lastOffset.y
        
        _lastOffset = offset
        
        offset.x *= 0.1
        offset.y *= 0.1
        var rx = offset.y; //offset.y > 0 ? log(1 + offset.y * offset.y) : -log(1 + offset.y * offset.y);
        var ry = offset.x; //offset.x > 0 ? log(1 + offset.x * offset.x) : -log(1 + offset.x * offset.x);
        
        ry *= 0.05
        rx *= 0.05
        
        #if os(iOS)
            rx = -rx //on iOS, invert rotation on the X axis
        #endif
        
        if rx > 0.5 {
            rx = 0.5
            _initialOffset.y -= tr.y
            _lastOffset.y -= tr.y
        }
        if rx < -.pi/2 {
            rx = -.pi/2
            _initialOffset.y -= tr.y
            _lastOffset.y -= tr.y
        }
        
        let MAX_RY = CGFloat(.pi/4*1.5)
        if ry > MAX_RY {
            ry = MAX_RY
            _initialOffset.x -= tr.x
            _lastOffset.x -= tr.x
        }
        if ry < -MAX_RY {
            ry = -MAX_RY
            _initialOffset.x -= tr.x
            _lastOffset.x -= tr.x
            
        }
        
        ry = -ry
        
        _cameraHandle.eulerAngles = SCNVector3Make(SCNVectorFloat(rx), SCNVectorFloat(ry), 0)
    }
    
    //MARK: -
    //MARK: UIKit configuration
    
    #if os(iOS)
    override var shouldAutorotate : Bool {
        return true
    }
    
    override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    #endif
    
    //MARK: -
    //MARK: Physics
    
    private let BOX_W: CGFloat = 8
    
    // return a new physically based box at the specified position
    // sometimes generate a ball instead of a box for more variety
    private func boxAtPosition(_ position: SCNVector3) -> SCNNode {
        struct My {
            static var boxes: [SCNNode] = []
            static var count = 0
        }
        
        if My.boxes.isEmpty {
            My.boxes.reserveCapacity(4)
            
            var box = SCNNode()
            box.geometry = SCNBox(width: BOX_W, height: BOX_W, length: BOX_W, chamferRadius: 0.1)
            box.geometry!.firstMaterial!.diffuse.contents = "WoodCubeA.jpg"
            box.geometry!.firstMaterial!.diffuse.mipFilter = .linear
            box.physicsBody = .dynamic()
            
            My.boxes.append(box)
            
            box = box.clone()
            box.geometry = (box.geometry!.copy() as! SCNGeometry)
            box.geometry!.firstMaterial = (box.geometry!.firstMaterial!.copy() as! SCNMaterial)
            box.geometry!.firstMaterial!.diffuse.contents = "WoodCubeB.jpg"
            My.boxes.append(box)
            
            box = box.clone()
            box.geometry = (box.geometry!.copy() as! SCNGeometry)
            box.geometry!.firstMaterial = (box.geometry!.firstMaterial!.copy() as! SCNMaterial)
            box.geometry!.firstMaterial!.diffuse.contents = "WoodCubeC.jpg"
            My.boxes.append(box)
            
            let ball = SCNNode()
            let sphere = SCNSphere(radius: BOX_W * 0.75)
            ball.geometry = sphere
            ball.geometry!.firstMaterial!.diffuse.wrapS = .repeat
            ball.geometry!.firstMaterial!.diffuse.contents = "ball.jpg"
            ball.geometry!.firstMaterial!.reflective.contents = "envmap.jpg"
            ball.geometry!.firstMaterial!.fresnelExponent = 1.0
            ball.physicsBody = .dynamic()
            ball.physicsBody!.restitution = 0.9
            My.boxes.append(ball)
        }
        
        My.count += 1
        
        var index = My.count % 3
        if My.count == 1 || (My.count&7) == 7 {
            index = 3
        }
        
        let item = My.boxes[index].clone()
        item.position = position
        
        return item
    }
    
    //apply an explosion force at the specified location to the specified nodes
    //remove from the nodes from the scene graph is removeOnCompletion is set to yes
    private func explosionAt(_ center: SCNVector3, receivers nodes: [SCNNode], removeOnCompletion: Bool) {
        var c = SCNVector3ToGLKVector3(center)
        
        for node in nodes {
            let p = SCNVector3ToGLKVector3(node.presentation.position)
            
            c.v.1 = removeOnCompletion ? -20 : -90
            c.v.2 = removeOnCompletion ? 0 : 50
            var direction = GLKVector3Subtract(p, c)
            
            c.v.1 = 0
            c.v.2 = 0
            let dist = GLKVector3Subtract(p, c)
            
            let force = removeOnCompletion ? 2000 : 1000 * (1.0 + fabs(c.x) / 100.0)
            let distance = GLKVector3Length(dist)
            
            if removeOnCompletion {
                if direction.x < 500.0 && direction.x > 0 {direction.v.0 += 500}
                if direction.x > -500.0 && direction.x < 0 {direction.v.0 -= 500}
                node.physicsBody?.collisionBitMask = 0x0
            }
            
            //normalise
            direction = GLKVector3Normalize(direction)
            direction = GLKVector3MultiplyScalar(direction, Float(FACTOR) * force / max(20.0, distance))
            
            node.physicsBody?.applyForce(SCNVector3FromGLKVector3(direction), at: removeOnCompletion ? SCNVector3Zero : SCNVector3Make(randFloat(-0.2, 0.2), randFloat(-0.2, 0.2), randFloat(-0.2, 0.2)) , asImpulse: true)
            
            if removeOnCompletion {
                node.runAction(.sequence([.wait(duration: 1.0), .fadeOut(duration: 0.125)]))
            }
        }
    }
    
    // present physics slide
    private func showPhysicsSlide() {
        let count = 80
        let spread: SCNVectorFloat = 6
        
        let scene = (self.view as! SCNView).scene!
        
        //tweak physics
        scene.physicsWorld.gravity = SCNVector3Make(0, -70, 0)
        
        //add invisible wall
        scene.rootNode.addChildNode(_invisibleWallForPhysicsSlide)
        
        // drop rigid bodies cubes
        let intervalTime = Int(Double(NSEC_PER_SEC) * 10.0 / Double(count))
        
        let queue = DispatchQueue.main
        _timer = DispatchSource.makeTimerSource(flags: [], queue: queue)
//        _timer!.setTimer(start: DispatchTime.now() + Double(Int64(NSEC_PER_SEC)) / Double(NSEC_PER_SEC), interval: intervalTime, leeway: 0); // every ms
        //DispatchTimeInterval
        _timer!.schedule(deadline: DispatchTime.now() + 1.0, repeating: .nanoseconds(intervalTime), leeway: .seconds(0)) // every ms
        
        var remainingCount = count
        var right = false
        
        _timer!.setEventHandler {
            
            if self._step > 1 {
                self._timer!.cancel()
                return
            }
            
            SCNTransaction.begin()
            
            let pos = SCNVector3Make(right ? 100 : -100, 50, 0)
            
            let box = self.boxAtPosition(pos)
            
            //add to scene
            self._scene.rootNode.addChildNode(box)
            
            
            box.physicsBody?.velocity = SCNVector3Make(FACTOR * (right ? -50 : 50), FACTOR * (30+randFloat(-spread, spread)), FACTOR * (randFloat(-spread, spread)))
            box.physicsBody?.angularVelocity = SCNVector4Make(randFloat(-1, 1),randFloat(-1, 1),randFloat(-1, 1),randFloat(-3, 3))
            SCNTransaction.commit()
            
            self._boxes.append(box)
            
            // ensure we stop firing
            remainingCount -= 1
            if remainingCount < 0 {
                self._timer!.cancel()
            }
            
            right = !right
        }
        
        _timer!.resume()
    }
    
    //remove physics slide
    private func orderOutPhysics() {
        //move physics out
        self.explosionAt(SCNVector3Make(0, 0, 0), receivers: _boxes, removeOnCompletion: true)
        _boxes.removeAll()
        
        //add invisible wall
        let scene = (self.view as! SCNView).scene!
        scene.rootNode.addChildNode(_invisibleWallForPhysicsSlide)
    }
    
    //MARK: - Particles
    
    //present particle slide
    private func showParticlesSlide() {
        //restore defaults
        (self.view as! SCNView).scene!.physicsWorld.gravity = SCNVector3Make(0, -9.8, 0)
        
        //add truck
        let fireTruckScene = SCNScene(named: "firetruck.dae", inDirectory: "assets.scnassets/models/", options: nil)!
        let fireTruck = fireTruckScene.rootNode.childNode(withName: "firetruck", recursively: true)!
        let emitter = fireTruck.childNode(withName: "emitter", recursively: true)!
        _handle = fireTruck.childNode(withName: "handle", recursively: true)
        
        fireTruck.position = SCNVector3Make(120, 10, 0);
        fireTruck.position = SCNVector3Make(120, 10, 0)
        fireTruck.scale = SCNVector3Make(0.2, 0.2, 0.2)
        fireTruck.rotation = SCNVector4Make(0, 1, 0, .pi/2)
        
        _scene.rootNode.addChildNode(fireTruck)
        
        //add fire container
        let fireContainerScene = SCNScene(named: "bac.dae", inDirectory: "assets.scnassets/models/", options: nil)!
        _fireContainer = fireContainerScene.rootNode.childNode(withName: "box", recursively: true)!
        _fireContainer!.scale = SCNVector3Make(0.5, 0.25, 0.25)
        _scene.rootNode.addChildNode(_fireContainer!)
        
        //preload it to avoid frame drop
        (self.view as! SCNView).prepare(_scene, shouldAbortBlock: nil)
        
        _fireTruck = fireTruck
        
        //collider
        let colliderNode = SCNNode()
        colliderNode.geometry = SCNBox(width: 50, height: 2, length: 25, chamferRadius: 0)
        colliderNode.geometry!.firstMaterial!.diffuse.contents = "assets.scnassets/textures/train_wood.jpg"
        colliderNode.position = SCNVector3Make(60, 260, 5)
        _scene.rootNode.addChildNode(colliderNode)
        
        let moveIn = SCNAction.moveBy(x: 0, y: -215, z: 0, duration: 1.0)
        moveIn.timingMode = SCNActionTimingMode.easeOut
        colliderNode.runAction(.sequence([.wait(duration: 2), moveIn]))
        
        let animation = CABasicAnimation(keyPath: "eulerAngles")
        animation.fromValue = SCNVector3Make(0, 0, 0)
        animation.toValue = SCNVector3Make(0, 0, 2 * .pi)
        animation.beginTime = CACurrentMediaTime() + 0.5
        animation.duration = 2
        animation.repeatCount = MAXFLOAT
        colliderNode.addAnimation(animation, forKey: nil)
        _collider = colliderNode
        
        //add fire
        let fireHolder = SCNNode()
        _emitter = fireHolder
        fireHolder.position = SCNVector3Make(0,0,0)
        var ps = SCNParticleSystem(named: "fire.scnp", inDirectory: "assets.scnassets/particles/")!
        _smoke = SCNParticleSystem(named: "smoke.scnp", inDirectory: "assets.scnassets/particles/")!
        _smoke.birthRate = 0
        fireHolder.addParticleSystem(ps)
        
        let smokeEmitter = SCNNode()
        smokeEmitter.position = SCNVector3Make(0, 0, 0.5)
        smokeEmitter.addParticleSystem(_smoke)
        fireHolder.addChildNode(smokeEmitter)
        _scene.rootNode.addChildNode(fireHolder)
        
        _fire = ps
        
        //add water
        ps = SCNParticleSystem(named: "sparks.scnp", inDirectory: "assets.scnassets/particles/")!
        ps.birthRate = 0
        ps.speedFactor = 3.0
        ps.colliderNodes = [_floorNode!, colliderNode]
        emitter.addParticleSystem(ps)
        
        let tr = SCNAction.move(by: SCNVector3Make(60, 0, 0), duration: 1)
        tr.timingMode = .easeInEaseOut
        
        _cameraHandle.runAction(.sequence([.wait(duration: 2), tr, .run{node in
            ps.birthRate = 300
            }]))
    }
    
    //remove particle slide
    private func orderOutParticles() {
        //remove fire truck
        _fireTruck?.removeFromParentNode()
        _emitter?.removeFromParentNode()
        _collider?.removeFromParentNode()
        _fireContainer?.removeFromParentNode()
        _fireContainer = nil
        _collider = nil
        _emitter = nil
        _fireTruck = nil
    }
    
    //MARK: -
    //MARK: PhysicsFields
    
    private func moveEmitter(to p: CGPoint) {
        let scnView = self.view as! SCNView
        let pTmp = scnView.projectPoint(SCNVector3Make(0, 0, 50))
        var p3d = scnView.unprojectPoint(SCNVector3Make(SCNVectorFloat(p.x), SCNVectorFloat(p.y), pTmp.z))
        p3d.z = 50
        p3d.y = max(p3d.y, 5)
        _fieldOwner?.position = p3d
        _fieldOwner?.physicsField!.strength = 10000.0
    }
    
    
    //present physics field slide
    private func showPhysicsFields() {
        let dz: SCNVectorFloat = 50
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.75
        _spotLightNode.light!.color = SKColor(white: 0.5, alpha: 1.0)
        _ambientLightNode.light!.color = SKColor.black
        SCNTransaction.commit()
        
        //remove gravity for this slide
        _scene.physicsWorld.gravity = SCNVector3Zero
        
        //move camera
        let tr = SCNAction.move(by: SCNVector3Make(0, 0, dz), duration: 1)
        tr.timingMode = .easeInEaseOut
        _cameraHandle.runAction(tr)
        
        //add particles
        _fieldEmitter = SCNNode()
        _fieldEmitter!.position = SCNVector3Make(_cameraHandle.position.x, 5, dz)
        
        let ps = SCNParticleSystem(named: "bubbles.scnp", inDirectory: "assets.scnassets/particles/")!
        
        ps.particleColor = SKColor(red: 0.8, green: 0.0, blue: 0.0, alpha: 1.0)
        ps.particleColorVariation = SCNVector4Make(0.3, 0.2, 0.3, 0.0)
        ps.sortingMode = .distance
        ps.blendMode = .alpha
        let cubeMap = ["right.jpg", "left.jpg", "top.jpg", "bottom.jpg", "front.jpg", "back.jpg"]
        ps.particleImage = cubeMap
        ps.fresnelExponent = 2
        ps.colliderNodes = [_floorNode, _mainWall]
        
        ps.emitterShape = SCNBox(width: 200, height: 0, length: 100, chamferRadius: 0)
        
        _fieldEmitter!.addParticleSystem(ps)
        _scene.rootNode.addChildNode(_fieldEmitter!)
        
        //field
        _fieldOwner = SCNNode()
        _fieldOwner!.position = SCNVector3Make(_cameraHandle.position.x, 50, dz+5)
        
        let field = SCNPhysicsField.radialGravity()
        field.halfExtent = SCNVector3Make(100, 100, 100)
        field.minimumDistance = 20.0
        field.falloffExponent = 0
        //_fieldOwner.physicsField.strength = 0.0
        _fieldOwner!.physicsField = field
        _fieldOwner!.physicsField!.strength = 0.0 //###
        _scene.rootNode.addChildNode(_fieldOwner!)
    }
    
    //remove physics field slide
    private func orderOutPhysicsFields() {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.75
        _spotLightNode.light!.color = SKColor(white: 1.0, alpha: 1.0)
        _ambientLightNode.light!.color = SKColor(white: 0.3, alpha: 1.0)
        SCNTransaction.commit()
        
        //move camera
        let dz: SCNVectorFloat = 50
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.75
        _cameraHandle.position = SCNVector3Make(_cameraHandle.position.x, _cameraHandle.position.y, _cameraHandle.position.z - dz)
        SCNTransaction.commit()
        
        _fieldEmitter?.removeFromParentNode()
        _fieldOwner?.removeFromParentNode()
        _fieldEmitter = nil
        _fieldOwner = nil
    }
    
    //MARK: -
    //MARK: SpriteKit
    
    private let SPRITE_SIZE: CGFloat = 256
    
    // add a color "splash" at the specified location in the SKScene used as a material
    private func addPaintAtLocation(_ _p: CGPoint, color: SKColor) {
        if let skScene = _torus.geometry!.firstMaterial!.diffuse.contents as? SKScene {
            
            //update the contents of skScene by adding a splash of "color" at p (normalized [0, 1])
            var p = _p
            p.x *= SPRITE_SIZE
            p.y *= SPRITE_SIZE
            
            var node: SKNode = SKSpriteNode()
            node.position = p
            node.xScale = 0.33
            
            let subNode = SKSpriteNode(imageNamed: "splash.png")
            subNode.zRotation = randFloat(0.0, 2.0 * .pi)
            subNode.color = color
            subNode.colorBlendFactor = 1
            
            node.addChild(subNode)
            skScene.addChild(node)
            
            //remove color splash at some point
            node.run(.sequence([.wait(forDuration: 5), .removeFromParent()]));
            
            if p.x < 16 {
                node = node.copy() as! SKNode
                p.x = SPRITE_SIZE + p.x
                node.position = p
                skScene.addChild(node)
            } else if p.x > SPRITE_SIZE-16 {
                node = node.copy() as! SKNode
                p.x = (p.x - SPRITE_SIZE)
                node.position = p
                skScene.addChild(node)
            }
        }
    }
    
    // physics contact delegate
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        var ball: SCNNode? = nil
        var other: SCNNode? = nil
        
        if contact.nodeA.physicsBody!.type == .dynamic {
            ball = contact.nodeA
            other = contact.nodeB
        } else if contact.nodeB.physicsBody!.type == .dynamic {
            ball = contact.nodeB
            other = contact.nodeA
        }
        
        if let ball = ball {
            let plokCopy = _plok.copy() as! SCNParticleSystem
            plokCopy.particleImage = _plok.particleImage; // to workaround an bug in seed #1
            plokCopy.particleColor = ball.geometry!.firstMaterial!.diffuse.contents as! SKColor
            _scene.addParticleSystem(plokCopy, transform: SCNMatrix4MakeTranslation(contact.contactPoint.x, contact.contactPoint.y, contact.contactPoint.z))
            
            if other !== _torus {
                let node = _splashNode.clone()
                node.geometry = (node.geometry!.copy() as! SCNGeometry)
                node.geometry!.firstMaterial = (node.geometry!.firstMaterial!.copy() as! SCNMaterial)
                node.geometry!.firstMaterial!.diffuse.contents = plokCopy.particleColor
                node.castsShadow = false
                //node.geometry!.firstMaterial!.readsFromDepthBuffer = false
                node.geometry!.firstMaterial!.writesToDepthBuffer = false
                
                struct My {
                    static var eps: SCNVectorFloat = 1
                }
                My.eps += 0.0002
                node.position = SCNVector3Make(contact.contactPoint.x, contact.contactPoint.y, _mainWall.position.z + My.eps)
                
                node.runAction(.sequence([
                    .fadeOut(duration: 1.5),
                    .removeFromParentNode()
                    ]))
                _scene.rootNode.addChildNode(node)
                
            } else {
                //compute texture coordinate
                let scnview = self.view as! SCNView
                let pointA = SCNVector3Make(contact.contactPoint.x, contact.contactPoint.y, contact.contactPoint.z+20)
                let pointB = SCNVector3Make(contact.contactPoint.x, contact.contactPoint.y, contact.contactPoint.z-20)
                
                let results = scnview.scene!.rootNode.hitTestWithSegment(from: pointA, to: pointB, options: [SCNHitTestOption.rootNode.rawValue: _torus])
                
                if !results.isEmpty {
                    let hit = results[0]
                    self.addPaintAtLocation(hit.textureCoordinates(withMappingChannel: 0), color: plokCopy.particleColor)
                    
                }
            }
            
            ball.removeFromParentNode()
        }
    }
    
    //present spritekit integration slide
    private func showSpriteKitSlide() {
        //place camera
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 2.0
        _cameraHandle.position = SCNVector3Make(_cameraHandle.position.x+200, 60, 0)
        SCNTransaction.commit()
        
        
        //load plok particles
        _plok = SCNParticleSystem(named: "plok.scnp", inDirectory: "assets.scnassets/particles")
        
        let W: CGFloat = 50
        
        //create a spinning object
        _torus = SCNNode()
        _torus.position = SCNVector3Make(_cameraHandle.position.x, 60, 10)
        _torus.geometry = SCNTorus(ringRadius: W/2, pipeRadius: W/6)
        _torus.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: _torus.geometry!, options: [.type: SCNPhysicsShape.ShapeType.concavePolyhedron]))
        _torus.opacity = 0.0
        
        // create a splash
        _splashNode = SCNNode()
        _splashNode.geometry = SCNPlane(width: 10, height: 10)
        _splashNode.geometry!.firstMaterial!.transparent.contents = "splash.png"
        
        
        let material = _torus.geometry!.firstMaterial!
        material.specular.contents = SKColor(white: 0.5, alpha: 1)
        material.shininess = 2.0
        
        material.normal.contents = "wood-normal.png"
        
        _scene.rootNode.addChildNode(_torus)
        _torus.runAction(.repeatForever(.rotate(by: .pi*2, around: SCNVector3Make(0.4, 1, 0), duration: 8)))
        
        //preload it to avoid frame drop
        (self.view as! SCNView).prepare(_scene, shouldAbortBlock: nil)
        
        _scene.physicsWorld.contactDelegate = self
        
        //setup material
        let skScene = SKScene(size: CGSize(width: SPRITE_SIZE, height: SPRITE_SIZE))
        skScene.backgroundColor = .white
        material.diffuse.contents = skScene
        
        //tweak physics
        (self.view as! SCNView).scene!.physicsWorld.gravity = SCNVector3Make(0, -70, 0)
        
        // show the torus
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 1.0
        _torus.opacity = 1.0
        SCNTransaction.commit()
    }
    
    
    func launchColorBall() {
        let ball = SCNNode()
        let sphere = SCNSphere(radius: 2)
        ball.geometry = sphere
        let hue = CGFloat(arc4random())/CGFloat(UInt32.max)
        ball.geometry!.firstMaterial?.diffuse.contents = SKColor(hue: hue, saturation: 1, brightness: 1, alpha: 1)
        ball.geometry!.firstMaterial?.reflective.contents = "envmap.jpg"
        ball.geometry!.firstMaterial?.fresnelExponent = 1.0
        ball.physicsBody = .dynamic()
        ball.physicsBody!.restitution = 0.9
        ball.physicsBody!.categoryBitMask = 0x4
        if #available(OSX 10.11, iOS 9.0, *) {
            ball.physicsBody!.contactTestBitMask = ~0
        }
        ball.physicsBody!.collisionBitMask = ~(0x4)
        //ball.physicsBody!.contactTestBitMask = 0xff
    
        ball.position = SCNVector3Make(_cameraHandle.position.x, 20, 100)
    
        //add to scene
        _scene.rootNode.addChildNode(ball)
    
        let PAINT_FACTOR = SCNVectorFloat(2)
    
        ball.physicsBody!.velocity = SCNVector3Make(
            PAINT_FACTOR * randFloat(-10, 10),
            (75+randFloat(0, 35)),
            PAINT_FACTOR * -30.0)
    }
    
    private func orderOutSpriteKit() {
        _torus.removeFromParentNode()
        _scene.physicsWorld.contactDelegate = nil
    }
    
    //MARK: - Shaders
    
    private func showNextShaderStage() {
        _shaderStage += 1
        
        //retrieve the node that owns the shader modifiers
        guard let node = _shadedNode else {fatalError()}
        
        switch _shaderStage {
        case 1: // Geometry
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 1.0
            node.geometry!.shaderModifiers = [.geometry: _geomModifier,
                .lightingModel: _lightModifier]
            
            node.geometry!.setValue(3.0, forKey: "Amplitude")
            node.geometry!.setValue(0.25, forKey: "Frequency")
            node.geometry!.setValue(0.0, forKey: "lightIntensity")
            SCNTransaction.commit()
        case 2: // Surface
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.5
            node.geometry!.setValue(0.0, forKey: "Amplitude")
            SCNTransaction.completionBlock = {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 1.5
                node.geometry!.shaderModifiers = [.surface: self._surfModifier,
                    .lightingModel: self._lightModifier]
                node.geometry!.setValue(1.0, forKey: "surfIntensity")
                SCNTransaction.commit()
            }
            SCNTransaction.commit()
        case 3: // Fragment
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.5
            
            node.geometry!.setValue(0.0, forKey: "surfIntensity")
            SCNTransaction.completionBlock = {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 1.5
                node.geometry!.shaderModifiers = [.fragment: self._fragModifier,
                    .lightingModel: self._lightModifier]
                node.geometry!.setValue(1.0, forKey: "fragIntensity")
                node.geometry!.setValue(1.0, forKey: "lightIntensity")
                SCNTransaction.commit()
            }
            SCNTransaction.commit()
            
        case 4: // None
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.5
            node.geometry!.setValue(0.0, forKey: "fragIntensity")
            node.geometry!.setValue(0.0, forKey: "lightIntensity")
            _shaderStage = 0
            SCNTransaction.completionBlock = {
                node.geometry!.shaderModifiers = nil
            }
            SCNTransaction.commit()
        default:
            break
        }
    }
    
    private func showShadersSlide() {
        _shaderStage = 0
        
        //move the camera back
        //place camera
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 1.0
        _cameraHandle.position = SCNVector3Make(_cameraHandle.position.x+180, 60, 0)
        _cameraHandle.eulerAngles = SCNVector3Make(-.pi/4*0.3, 0, 0)
        
        _spotLightNode.light!.spotOuterAngle = 55
        SCNTransaction.commit()
        
        _shaderGroupNode = SCNNode()
        _shaderGroupNode!.position = SCNVector3Make(_cameraHandle.position.x, -5, 20)
        _scene.rootNode.addChildNode(_shaderGroupNode!)
        
        //add globe stand
        let globe = SCNScene(named: "assets.scnassets/models/globe.dae")!.rootNode.childNode(withName: "globe", recursively: true)!
        
        _shaderGroupNode!.addChildNode(globe)
        
        //show shader modifiers
        //add spheres
        let sphere = SCNSphere(radius: 28)
        sphere.segmentCount = 48
        sphere.firstMaterial!.diffuse.contents = "earth-diffuse.jpg"
        sphere.firstMaterial!.specular.contents = "earth-specular.jpg"
        sphere.firstMaterial!.specular.intensity = 0.2
        
        sphere.firstMaterial!.shininess = 0.1
        sphere.firstMaterial!.reflective.contents = "envmap.jpg"
        sphere.firstMaterial!.reflective.intensity = 0.5
        sphere.firstMaterial!.fresnelExponent = 2
        
        //GEOMETRY
        let node = globe.childNode(withName: "globeAttach", recursively: true)!
        node.geometry = sphere
        node.scale = SCNVector3Make(3, 3, 3)
        
        node.runAction(.repeatForever(.rotateBy(x: 0, y: .pi, z: 0, duration: 6.0)))
        
        _geomModifier = try! String(contentsOfFile: Bundle.main.path(forResource: "sm_geom", ofType: "shader")!, encoding: .utf8)
        _surfModifier = try! String(contentsOfFile: Bundle.main.path(forResource: "sm_surf", ofType: "shader")!, encoding: .utf8)
        _fragModifier = try! String(contentsOfFile: Bundle.main.path(forResource: "sm_frag", ofType: "shader")!, encoding: .utf8)
        _lightModifier = try! String(contentsOfFile: Bundle.main.path(forResource: "sm_light", ofType: "shader")!, encoding: .utf8)
        
        node.geometry!.setValue(0.0, forKey: "Amplitude")
        node.geometry!.setValue(0.0, forKey: "lightIntensity")
        node.geometry!.setValue(0.0, forKey: "surfIntensity")
        node.geometry!.setValue(0.0, forKey: "fragIntensity")
        
        _shadedNode = node
        
        //redraw forever
        (self.view as! SCNView).isPlaying = true
        (self.view as! SCNView).loops = true
    }
    
    private func orderOutShaders() {
        _shaderGroupNode?.runAction(.sequence([.scale(to: 0.01, duration: 1.0), .removeFromParentNode()]))
        _shaderGroupNode = nil
    }
    
    //MARK: - Presentation logic
    
    private func presentStep(_ step: Int) {
        let overlay = (self.view as! SCNView).overlaySKScene as! AAPLSpriteKitOverlayScene
        
        if _cameraHandleTransforms[step].m11 == 0 {
            _cameraHandleTransforms[step] = _cameraHandle.transform
            _cameraOrientationTransforms[step] = _cameraOrientation.transform
        }
        
        switch step {
        case 1:
            overlay.showLabel("Physics")
            overlay.run(.sequence([.wait(forDuration: 2), .run{
                if self._step == 1 {
                    overlay.showLabel(nil)
                }
                }]))
            
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.0) {
                self.showPhysicsSlide()
            }
        case 2:
            overlay.showLabel("Particles")
            overlay.run(.sequence([.wait(forDuration: 4), .run{
                if self._step == 2 {
                    overlay.showLabel(nil)
                }
                }]))
            
            self.showParticlesSlide()
        case 3:
            overlay.showLabel("Physics Fields")
            overlay.run(.sequence([.wait(forDuration: 2), .run{
                if self._step == 3 {
                    overlay.showLabel(nil)
                }
                }]))
            
            self.showPhysicsFields()
        case 4:
            overlay.showLabel("SceneKit + SpriteKit")
            overlay.run(.sequence([.wait(forDuration: 4), .run{
                if self._step == 4 {
                    overlay.showLabel(nil)
                }
                }]))
            
            self.showSpriteKitSlide()
        case 5:
            overlay.showLabel("SceneKit + Shaders")
            self.showShadersSlide()
        default:
            break
        }
    }
    
    private func orderOutStep(_ step: Int) {
        switch step {
        case 1:
            self.orderOutPhysics()
        case 2:
            self.orderOutParticles()
        case 3:
            self.orderOutPhysicsFields()
        case 4:
            self.orderOutSpriteKit()
        case 5:
            self.orderOutShaders()
        default:
            break
        }
    }
    
    private func next() {
        if _step >= 5 {
            return
        }
        
        self.orderOutStep(_step)
        _step += 1
        self.presentStep(_step)
    }
    
    private func previous() {
        if _step <= 1 {
            return
        }
        
        self.orderOutStep(_step)
        _step -= 1
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.75
        SCNTransaction.completionBlock = {
            self.presentStep(self._step)
        }
        
        _cameraHandle.transform = _cameraHandleTransforms[_step]
        _cameraOrientation.transform = _cameraOrientationTransforms[_step]
        
        SCNTransaction.commit()
    }
    
    //MARK: - Rendering Loop
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        if _step == 2 && _hitFire {
            var fire = _fire.birthRate
            
            if fire > 0 {
                fire -= 0.1
                _smoke.birthRate = (1.0-(fire / MAX_FIRE)) * MAX_SMOKE
                _fire.birthRate = max(0,fire)
            } else {
                var smoke = _smoke.birthRate
                if smoke > 0 {
                    smoke -= 0.03
                }
                
                _smoke.birthRate = max(0,smoke)
            }
        }
        
        
        if _step == 4 { //launch color at some interval
            struct My {
                static var lastTime: TimeInterval = 0
            }
            
            if time - My.lastTime > 0.1 {
                My.lastTime = time
                
                self.launchColorBall()
            }
        }
    }
    
    //MARK: - Gestures
    
    func gestureDidEnd() {
        if _step == 3 {
            //bubbles
            _fieldOwner?.physicsField!.strength = 0.0
        }
    }
    
    func gestureDidBegin() {
        _initialOffset = _lastOffset
    }
    
    #if os(iOS)
    @objc func handleDoubleTap(_ gestureRecognizer: UIGestureRecognizer) {
        self.restoreCameraAngle()
    }
    
    @objc func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) { //###
        if gestureRecognizer.state == .ended {
            self.gestureDidEnd()
            return
        }
        
        if gestureRecognizer.state == .began {
            self.gestureDidBegin()
            return
        }
        
        if gestureRecognizer.numberOfTouches == 2 {
            self.tiltCameraWithOffset(gestureRecognizer.translation(in: self.view))
            
        } else {
            let p = gestureRecognizer.location(in: self.view)
            self.handlePanAtPoint(p)
        }
    }
    
    @objc func handleTap(_ gestureRecognizer: UIGestureRecognizer) {
        let p = gestureRecognizer.location(in: self.view)
        self.handleTapAtPoint(p)
    }
    #endif
    
    func handlePanAtPoint(_ p: CGPoint) {
        let scnView = self.view as! SCNView
        
        if _step == 2 {
            //particles
            let pTmp = scnView.projectPoint(SCNVector3Make(0, 0, 0))
            let p3d = scnView.unprojectPoint(SCNVector3Make(SCNVectorFloat(p.x), SCNVectorFloat(p.y), pTmp.z))
            let handlePos = _handle.worldTransform
            
            
            let dy = max(0, p3d.y - handlePos.m42)
            let dx = handlePos.m41 - p3d.x
            var angle = atan2(dy, dx)
            
            
            angle -= 35.0 * .pi / 180.0; //handle is 35 degree by default
            
            //clamp
            let MIN_ANGLE = -SCNVectorFloat.pi/2*0.1
            let MAX_ANGLE = SCNVectorFloat.pi*0.8
            if angle < MIN_ANGLE {angle = MIN_ANGLE}
            if angle > MAX_ANGLE {angle = MAX_ANGLE}
            
            
            let HIT_DELAY: Double = 3
            
            if angle <= 0.66 && angle >= 0.48 {
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + HIT_DELAY) {
                    //hit the fire!
                    self._hitFire = true
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + HIT_DELAY) {
                    //hit the fire!
                    self._hitFire = false
                }
            }
            
            _handle.rotation = SCNVector4Make(1, 0, 0, angle)
        }
        
        if _step == 3 {
            //bubbles
            self.moveEmitter(to: p)
        }
    }
    
    func handleDoubleTapAtPoint(_ p: CGPoint) {
        self.restoreCameraAngle()
    }
    
    private func preventAccidentalNext(_ delay: TimeInterval) {
        _preventNext = true
        
        //disable the next button for "delay" seconds to prevent accidental tap
        let overlay = (self.view as! SCNView).overlaySKScene as! AAPLSpriteKitOverlayScene
        overlay.nextButton.run(.fadeAlpha(by: -0.5, duration: 0.5))
        overlay.previousButton.run(.fadeAlpha(by: -0.5, duration: 0.5))
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + delay) {
            self._preventNext = false
            overlay.previousButton.run(.fadeAlpha(to: self._step > 1 ? 1 : 0, duration: 0.75))
            overlay.nextButton.run(.fadeAlpha(to: self._introductionStep == 0 && self._step < 5 ? 1 : 0, duration: 0.75))
        }
    }
    
    func handleTapAtPoint(_ p: CGPoint) {
        //test buttons
        let skScene = (self.view as! SCNView).overlaySKScene!
        let p2D = skScene.convertPoint(fromView: p)
        let node = skScene.atPoint(p2D)
        
        // wait X seconds before enabling the next tap to avoid accidental tap
        let ignoreNext = _preventNext
        
        if _introductionStep != 0 {
            //next introduction step
            if !ignoreNext {
                self.preventAccidentalNext(1)
                self.nextIntroductionStep()
            }
            return
        }
        
        if !ignoreNext {
            if _step == 0 || node.name == "next" || node.name == "back" {
                let shouldGoBack = node.name == "back"
                
                if  node.name == "next" {
                    (node as! SKSpriteNode).color = SKColor(red: 1, green: 0, blue: 0, alpha: 1)
                    node.run(.customAction(withDuration: 0.7) {node, elapsedTime in
                        (node as! SKSpriteNode).colorBlendFactor = 0.7 - elapsedTime
                        })
                }
                
                self.restoreCameraAngle()
                
                self.preventAccidentalNext(_step==1 ? 3 : 1)
                
                if shouldGoBack {
                    self.previous()
                } else {
                    self.next()
                }
                
                return
            }
        }
        
        if _step == 1 {
            //bounce physics!
            let scnView = self.view as! SCNView
            let pTmp = scnView.projectPoint(SCNVector3Make(0, 0, -60))
            var p3d = scnView.unprojectPoint(SCNVector3Make(SCNVectorFloat(p.x), SCNVectorFloat(p.y), pTmp.z))
            
            p3d.y = 0
            p3d.z = 0
            
            self.explosionAt(p3d, receivers: _boxes, removeOnCompletion: false)
        }
        if _step == 3 {
            //bubbles
            self.moveEmitter(to: p)
        }
        
        if _step == 5 {
            //shader
            self.showNextShaderStage()
        }
    }
    
}



// SpriteKit overlays
@objc(AAPLSpriteKitOverlayScene)
class AAPLSpriteKitOverlayScene: SKScene {
    private(set) var nextButton: SKNode
    private(set) var previousButton: SKNode!
    private var _size: CGSize = CGSize()
    private var _label: SKLabelNode?
    
    override init(size: CGSize) {
        _size = size
        //buttons
        nextButton = SKSpriteNode(imageNamed: "next.png")
        super.init(size: size)
        
        /* Setup your scene here */
        self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        self.scaleMode = .resizeFill
        
        var marginY: CGFloat = 60
        let maringX: CGFloat = -60
        #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .phone {
                marginY = 30
                marginY = 30 //###???
            }
        #endif
        
        nextButton.position = CGPoint(x: size.width * 0.5 + maringX, y: -size.height * 0.5 + marginY)
        nextButton.name = "next"
        nextButton.alpha = 0.01
        #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .phone {
                nextButton.xScale = 0.5
                nextButton.yScale = 0.5
            }
        #endif
        self.addChild(nextButton)
        
        previousButton = SKSpriteNode(color: SKColor.clear, size: nextButton.frame.size)
        previousButton.position = CGPoint(x: -(size.width * 0.5 + maringX), y: -size.height * 0.5 + marginY)
        previousButton.name = "back"
        previousButton.alpha = 0.01
        self.addChild(previousButton)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func showLabel(_ label: String?) {
        if _label == nil {
            _label = SKLabelNode(fontNamed: "Myriad Set")
            if _label == nil {
                _label = SKLabelNode(fontNamed: "Avenir-Heavy")
            }
            _label!.fontSize = 140
            _label!.position = CGPoint(x: 0, y: 0)
            
            self.addChild(_label!)
        } else {
            if label != nil {
                _label!.position = CGPoint(x: 0, y: _size.height * 0.25)
            }
        }
        
        guard let label = label else {
            _label!.run(.fadeOut(withDuration: 0.5))
            return
        }
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .phone {
            _label!.fontSize = label.count > 10 ? 50 : 80
        } else {
            _label!.fontSize = label.count > 10 ? 100 : 140
        }
        #else
        _label!.fontSize = label.count > 10 ? 100 : 140
        #endif
        
        _label!.text = label
        _label!.alpha = 0.0
        _label!.run(.sequence([.wait(forDuration: 0.5), .fadeIn(withDuration: 0.5)]))
    }
    
}
