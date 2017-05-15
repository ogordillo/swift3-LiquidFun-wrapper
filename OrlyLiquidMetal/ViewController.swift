//
//  ViewController.swift
//  OrlyLiquidMetal
//
//  Created by Orlando Gordillo on 5/14/17.
//  Copyright © 2017 Orlando Gordillo. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    let gravity: Float = 9.80665
    let ptmRatio: Float = 32.0
    let particleRadius: Float = 9
    var particleSystem: UnsafeMutableRawPointer!
    
    override func viewDidLoad() {
        LiquidFun.createWorld(withGravity: Vector2D(x: 0, y:-gravity))
        super.viewDidLoad()
       
        particleSystem = LiquidFun.createParticleSystem(withRadius:particleRadius / ptmRatio, dampingStrength: 0.2, gravityScale: 1, density: 1.2)
        
        
        let screenSize: CGSize = UIScreen.main.bounds.size
        let screenWidth = Float(screenSize.width)
        let screenHeight = Float(screenSize.height)
        
       
        
        LiquidFun.createParticleBox(forSystem: particleSystem,
                                             position: Vector2D(x: screenWidth * 0.5 / ptmRatio, y: screenHeight * 0.5 / ptmRatio),
                                             size: Size2D(width: 50 / ptmRatio, height: 50 / ptmRatio))
        
        printParticleInfo()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func printParticleInfo() {
        let count = Int(LiquidFun.particleCount(forSystem: particleSystem))
        print("There are \(count) particles present")
        
        var positions = (LiquidFun.particlePositions(forSystem: particleSystem)).assumingMemoryBound(to: Vector2D.self)
        
        for i in 0..<count {
            let position = positions[i]
            print("particle: \(i) position: (\(position.x), \(position.y))")
        }
    }


}

