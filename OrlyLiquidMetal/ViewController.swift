//
//  ViewController.swift
//  OrlyLiquidMetal
//
//  Created by Orlando Gordillo on 5/14/17.
//  Copyright © 2017 Orlando Gordillo. All rights reserved.
//

import UIKit
import CoreMotion
import AudioKit

class ViewController: UIViewController {

    let gravity: Float = 150
    let ptmRatio: Float = 32.0
    let particleRadius: Float = 5
    var particleSystem: UnsafeMutableRawPointer!
    
    var device: MTLDevice! = nil
    var metalLayer: CAMetalLayer! = nil
    
    var particleCount: Int = 0
    var vertexBuffer: MTLBuffer! = nil
    
    var uniformBuffer: MTLBuffer! = nil
    
    var pipelineState: MTLRenderPipelineState! = nil
    var commandQueue: MTLCommandQueue! = nil
    
    let motionManager: CMMotionManager = CMMotionManager()
    

    let microphone = AKMicrophone()
    
    var tracker : AKFrequencyTracker!
    var silence : AKBooster!
    
    override func viewDidAppear(_ animated: Bool) {
        AudioKit.output = silence
        AudioKit.start()
    }
    
   
    
    override func viewDidLoad() {
        LiquidFun.createWorld(withGravity: Vector2D(x: 0.0, y:0))
        super.viewDidLoad()
        
        tracker = AKFrequencyTracker.init(microphone, hopSize: 200, peakCount: 2000)
        silence = AKBooster(tracker, gain:0)
        
        particleSystem = LiquidFun.createParticleSystem(withRadius:particleRadius / ptmRatio, dampingStrength: 0.0, gravityScale: 1, density: 5)
        LiquidFun.setParticleLimitForSystem(particleSystem, maxParticles: 2250)
        
        
        
        let screenSize: CGSize = UIScreen.main.bounds.size
        let screenWidth = Float(screenSize.width)
        let screenHeight = Float(screenSize.height)
        
       
        
        LiquidFun.createParticleBox(forSystem: particleSystem,
                                             position: Vector2D(x: screenWidth * 0.5 / ptmRatio, y: screenHeight * 0.5 / ptmRatio),
                                             size: Size2D(width: 50 / ptmRatio, height: 50 / ptmRatio))
        
        
        LiquidFun.createEdgeBox(withOrigin: Vector2D(x: 0, y: 0),
                                          size: Size2D(width: screenWidth / ptmRatio, height: screenHeight / ptmRatio))
        
        
        createMetalLayer()
        refreshVertexBuffer()
        refreshUniformBuffer()
        buildRenderPipeline()
        render()
        
        let displayLink = CADisplayLink(target: self, selector: #selector(ViewController.update))
        displayLink.preferredFramesPerSecond = 60
        displayLink.add(to: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
        
        motionManager.startAccelerometerUpdates(to: OperationQueue(),
                                                       withHandler: { (accelerometerData, error) -> Void in
                                                        let acceleration = accelerometerData?.acceleration
                                                        let gravityX = self.gravity * Float((acceleration?.x)!)
                                                        let gravityY = self.gravity * Float((acceleration?.y)!)
                                                        
        })
        
        

        microphone.start()
        
    }
    
 

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func printParticleInfo() {
        let count = Int(LiquidFun.particleCount(forSystem: particleSystem))
        print("There are \(count) particles present")
        
        let positions = (LiquidFun.particlePositions(forSystem: particleSystem)).assumingMemoryBound(to: Vector2D.self)
        
        for i in 0..<count {
            let position = positions[i]
            print("particle: \(i) position: (\(position.x), \(position.y))")
        }
    }
    
    func createMetalLayer() {
        device = MTLCreateSystemDefaultDevice()
        
        metalLayer = CAMetalLayer()
        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
        metalLayer.frame = view.layer.frame
        view.layer.addSublayer(metalLayer)
    }
    
    func refreshVertexBuffer () {
        particleCount = Int(LiquidFun.particleCount(forSystem: particleSystem))
        let positions = LiquidFun.particlePositions(forSystem: particleSystem)
        let bufferSize = MemoryLayout<Float>.size * particleCount * 2
        vertexBuffer = device.makeBuffer(bytes: positions!, length: bufferSize, options: [])
    }
    
    func makeOrthographicMatrix(left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float) -> [Float] {
        let ral = right + left
        let rsl = right - left
        let tab = top + bottom
        let tsb = top - bottom
        let fan = far + near
        let fsn = far - near
        
        return [2.0 / rsl, 0.0, 0.0, 0.0,
                0.0, 2.0 / tsb, 0.0, 0.0,
                0.0, 0.0, -2.0 / fsn, 0.0,
                -ral / rsl, -tab / tsb, -fan / fsn, 1.0]
    }
    
    func refreshUniformBuffer () {
        // 1
        let screenSize: CGSize = UIScreen.main.bounds.size
        let screenWidth = Float(screenSize.width)
        let screenHeight = Float(screenSize.height)
        let ndcMatrix = makeOrthographicMatrix(left: 0, right: screenWidth,
                                               bottom: 0, top: screenHeight,
                                               near: -1, far: 1)
        var radius = particleRadius
        var ratio = ptmRatio
        
        // 2
        let floatSize = MemoryLayout<Float>.size
        let float4x4ByteAlignment = floatSize * 4
        let float4x4Size = floatSize * 16
        let paddingBytesSize = float4x4ByteAlignment - floatSize * 2
        let uniformsStructSize = float4x4Size + floatSize * 2 + paddingBytesSize
        
        // 3
        uniformBuffer = device.makeBuffer(length: uniformsStructSize, options: [])
        let bufferPointer = uniformBuffer.contents()
        memcpy(bufferPointer, ndcMatrix, float4x4Size)
        memcpy(bufferPointer + float4x4Size, &ratio, floatSize)
        memcpy(bufferPointer + float4x4Size + floatSize, &radius, floatSize)
    }
    
    func buildRenderPipeline(colorindex: Int = 0) {
        // 1
        let defaultLibrary = device.newDefaultLibrary()
        
        var fragmentProgram = defaultLibrary?.makeFunction(name: "basic_yellow_fragment")
        var vertexProgram = defaultLibrary?.makeFunction(name: "particle_vertex")
        
        switch colorindex {
        case 0:
            fragmentProgram = defaultLibrary?.makeFunction(name: "basic_yellow_fragment")
            vertexProgram = defaultLibrary?.makeFunction(name: "particle_vertex")
        case 1:
            fragmentProgram = defaultLibrary?.makeFunction(name: "basic_green_fragment")
            vertexProgram = defaultLibrary?.makeFunction(name: "particle_vertex")
        case 2:
            fragmentProgram = defaultLibrary?.makeFunction(name: "basic_red_fragment")
            vertexProgram = defaultLibrary?.makeFunction(name: "particle_vertex")
        case 3:
            fragmentProgram = defaultLibrary?.makeFunction(name: "basic_blue_fragment")
            vertexProgram = defaultLibrary?.makeFunction(name: "particle_vertex")
        case 4:
            fragmentProgram = defaultLibrary?.makeFunction(name: "basic_white_fragment")
            vertexProgram = defaultLibrary?.makeFunction(name: "particle_vertex")
        case 5:
            fragmentProgram = defaultLibrary?.makeFunction(name: "basic_pink_fragment")
            vertexProgram = defaultLibrary?.makeFunction(name: "particle_vertex")
        case 6:
            fragmentProgram = defaultLibrary?.makeFunction(name: "basic_orange_fragment")
            vertexProgram = defaultLibrary?.makeFunction(name: "particle_vertex")
        case 7:
            fragmentProgram = defaultLibrary?.makeFunction(name: "basic_skyblue_fragment")
            vertexProgram = defaultLibrary?.makeFunction(name: "particle_vertex")
        default:
            fragmentProgram =  defaultLibrary?.makeFunction(name: "basic_purple_fragment")
            vertexProgram =  defaultLibrary?.makeFunction(name: "particle_vertex")
            
        }
        
        
        // 2
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexProgram
        pipelineDescriptor.fragmentFunction = fragmentProgram
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        

        
        do{
            try pipelineState = device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        }catch is Error{
            print("error line 145 in viewcontroller")
        }
        
        if (pipelineState == nil) {
//            print("Error occurred when creating render pipeline state: \(pipelineError)");
        }
        
        // 3
        commandQueue = device.makeCommandQueue()
    }
    
    func render() {
        let drawable = metalLayer.nextDrawable()
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable?.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor =
            MTLClearColor(red: 0.0/255.0, green: 0.0/255.0, blue: 0.0/255.0, alpha: 1.0)
        
        
        
        let commandBuffer = commandQueue.makeCommandBuffer()
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        

            renderEncoder.setRenderPipelineState(pipelineState)
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, at: 0)
            renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, at: 1)
            
            renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: particleCount, instanceCount: 1)
            renderEncoder.endEncoding()
        
        
        commandBuffer.present(drawable!)
        commandBuffer.commit()
    }
    
    var fps = 420
    
    func update(displayLink:CADisplayLink) {
        autoreleasepool {
            LiquidFun.worldStep(displayLink.duration, velocityIterations: 8, positionIterations: 3)
            self.refreshVertexBuffer()
            self.render()
        }
    
    
    self.emitparticler5000()
    
    
    if(fps == 0)
    {
        fps = 420
        var index = Int(random(0,9))
        self.buildRenderPipeline(colorindex: index)
    }
        fps = fps - 1
        
        
        
        
    }
    
    func emitparticler5000()
    {
        
        
        var normalizedfrequency = tracker.frequency / 2000
        normalizedfrequency = normalizedfrequency * 100
        normalizedfrequency = normalizedfrequency * 10 * 3
        
        var normalizedamplitude = tracker.amplitude * 10 * 2
    
        
        
        
        
        if(gravity2 == 1)
        {
            
            
            if(normalizedamplitude > 2.5)
            {
                
                
                normalizedamplitude = normalizedamplitude / 4
                
                
                if(normalizedfrequency > 625)
                {
                    normalizedfrequency = 625
                }
                
                if(normalizedfrequency < 125)
                {
                    normalizedfrequency = 125
                }
                
                let position = Vector2D(x: Float(view.bounds.width - view.bounds.width + 100) / ptmRatio,
                                        y: Float(view.bounds.height - CGFloat(normalizedfrequency)) / ptmRatio)
                let size = Size2D(width: Float(normalizedamplitude), height: 100 / ptmRatio)
                LiquidFun.createParticleBox(forSystem: particleSystem, position: position, size: size)
            }
        }else{
            
            
            if(normalizedamplitude > 2.5)
            {
                normalizedamplitude = normalizedamplitude / 6
                
                if(normalizedfrequency > 625)
                {
                    normalizedfrequency = 625
                }
                
                if(normalizedfrequency < 125)
                {
                    normalizedfrequency = 125
                }
                
                
                var thing =  Float(view.bounds.height) - Float(view.bounds.height / 2)
            let position = Vector2D(x: Float(view.bounds.width - view.bounds.width/2) / ptmRatio,
                                    y: Float(thing) / ptmRatio)
            let size = Size2D(width: Float(normalizedamplitude), height: Float(normalizedamplitude))
            LiquidFun.createParticleSlinky(forSystem: particleSystem, position: position, size: size)
            }
        }
        
        print(normalizedamplitude, normalizedfrequency)
    }
    
    
    
    
    
    
    
    
    
    
    var gravity2 = 0
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touchObject in touches {
            if let touch = touchObject as? UITouch {
                let touchLocation = touch.location(in: view)
                let position = Vector2D(x: Float(touchLocation.x) / ptmRatio,
                                        y: Float(view.bounds.height - touchLocation.y) / ptmRatio)
                let size = Size2D(width: 100 / ptmRatio, height: 100 / ptmRatio)
                
                LiquidFun.createParticleSlinky(forSystem: particleSystem, position: position, size: size)
//                if(gravity2 == 0)
//                {
//                    gravity2 = 1
//                    LiquidFun.setGravity(Vector2D(x: 0.0, y: -gravity))
//                }
//                else if(gravity2 == 1){
//                    gravity2 = 2
//                    LiquidFun.setGravity(Vector2D(x: gravity, y: 0.0))
//                }
//                else if(gravity2 == 2)
//                {
//                    gravity2 = 3
//                    LiquidFun.setGravity(Vector2D(x: 0.0, y: gravity))
//                }
                if(gravity2 == 0)
                {
                    gravity2 = 1
                    LiquidFun.setGravity(Vector2D(x: -gravity, y: 0.0))
                }
                else if(gravity2 == 1)
                {
                    gravity2 = 0
                    LiquidFun.setGravity(Vector2D(x: 0.0, y: 0.0))
                }
                
                
            }
            super.touchesBegan(touches, with: event)
        }
    }
    
    @IBOutlet var audioInputPlot: EZAudioPlot!
    func setupPlot() {
        let plot = AKNodeOutputPlot(microphone, frame: audioInputPlot.bounds)
        plot.plotType = .rolling
        plot.shouldFill = true
        plot.shouldMirror = true
        plot.color = UIColor.blue
        audioInputPlot.addSubview(plot)
    }
    
    

}

