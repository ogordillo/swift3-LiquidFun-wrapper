//
//  LiquidFun.m
//  OrlyLiquidMetal
//
//  Created by Orlando Gordillo on 5/14/17.
//  Copyright © 2017 Orlando Gordillo. All rights reserved.
//

#import "LiquidFun.h"
#import "Box2D.h"

static b2World *world;


@implementation LiquidFun

+ (void)createWorldWithGravity:(Vector2D)gravity{
    world = new b2World(b2Vec2(gravity.x, gravity.y));
}

+ (void *)createParticleSystemWithRadius:(float)radius dampingStrength:(float)dampingStrength
                            gravityScale:(float)gravityScale density:(float)density {
    b2ParticleSystemDef particleSystemDef;
    particleSystemDef.radius = radius;
    particleSystemDef.dampingStrength = dampingStrength;
    particleSystemDef.gravityScale = gravityScale;
    particleSystemDef.density = density;
    
    b2ParticleSystem *particleSystem = world->CreateParticleSystem(&particleSystemDef);
    
    return particleSystem;
}

+ (void)createParticleBoxForSystem:(void *)particleSystem
                          position:(Vector2D)position size:(Size2D)size {
    b2PolygonShape shape;
    shape.SetAsBox(size.width * 0.5f, size.height * 0.5f);
    
    b2ParticleGroupDef particleGroupDef;
    particleGroupDef.flags = b2_waterParticle;
    particleGroupDef.position.Set(position.x, position.y);
    particleGroupDef.shape = &shape;
    
    ((b2ParticleSystem *)particleSystem)->CreateParticleGroup(particleGroupDef);
}

+ (int)particleCountForSystem:(void *)particleSystem {
    return ((b2ParticleSystem *)particleSystem)->GetParticleCount();
}

+ (void *)particlePositionsForSystem:(void *)particleSystem {
    return ((b2ParticleSystem *)particleSystem)->GetPositionBuffer();
}
@end
