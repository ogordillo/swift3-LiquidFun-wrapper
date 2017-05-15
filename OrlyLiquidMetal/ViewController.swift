//
//  ViewController.swift
//  OrlyLiquidMetal
//
//  Created by Orlando Gordillo on 5/14/17.
//  Copyright © 2017 Orlando Gordillo. All rights reserved.
//

import UIKit
import CoreMotion

class ViewController: UIViewController {

    let gravity: Float = 9.80665
    let ptmRatio: Float = 32.0
    let particleRadius: Float = 9
    var particleSystem: UnsafeMutableRawPointer!
    
    var device: MTLDevice! = nil
    var metalLayer: CAMetalLayer! = nil
    
    var particleCount: Int = 0
    var vertexBuffer: MTLBuffer! = nil
    
    var uniformBuffer: MTLBuffer! = nil
    
    var pipelineState: MTLRenderPipelineState! = nil
    var commandQueue: MTLCommandQueue! = nil
    
    let motionManager: CMMotionManager = CMMotionManager()
    
    
    override func viewDidLoad() {
        LiquidFun.createWorld(withGravity: Vector2D(x: 0, y:-gravity))
        super.viewDidLoad()
       
        particleSystem = LiquidFun.createParticleSystem(withRadius:particleRadius / ptmRatio, dampingStrength: 0.2, gravityScale: 1, density: 1.2)
        LiquidFun.setParticleLimitForSystem(particleSystem, maxParticles: 1500)
        
        
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
        displayLink.preferredFramesPerSecond = 30
        displayLink.add(to: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
        
        motionManager.startAccelerometerUpdates(to: OperationQueue(),
                                                       withHandler: { (accelerometerData, error) -> Void in
                                                        let acceleration = accelerometerData?.acceleration
                                                        let gravityX = self.gravity * Float((acceleration?.x)!)
                                                        let gravityY = self.gravity * Float((acceleration?.y)!)
                                                        LiquidFun.setGravity(Vector2D(x: gravityX, y: gravityY))
        })
        
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
    
    func buildRenderPipeline() {
        // 1
        let defaultLibrary = device.newDefaultLibrary()
        let fragmentProgram = defaultLibrary?.makeFunction(name: "basic_fragment")
        let vertexProgram = defaultLibrary?.makeFunction(name: "particle_vertex")
        
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
            MTLClearColor(red: 0.0, green: 104.0/255.0, blue: 5.0/255.0, alpha: 1.0)
        
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
    
    
    func update(displayLink:CADisplayLink) {
        autoreleasepool {
            LiquidFun.worldStep(displayLink.duration, velocityIterations: 8, positionIterations: 3)
            self.refreshVertexBuffer()
            self.render()
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touchObject in touches {
            if let touch = touchObject as? UITouch {
                let touchLocation = touch.location(in: view)
                let position = Vector2D(x: Float(touchLocation.x) / ptmRatio,
                                        y: Float(view.bounds.height - touchLocation.y) / ptmRatio)
                let size = Size2D(width: 100 / ptmRatio, height: 100 / ptmRatio)
                LiquidFun.createParticleBox(forSystem: particleSystem, position: position, size: size)
            }
            super.touchesBegan(touches, with: event)
        }
    }
    


}

