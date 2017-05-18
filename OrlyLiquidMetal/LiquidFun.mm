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
    shape.SetAsBox(size.width * 1.2f, size.height * 0.025f);
    
    b2ParticleGroupDef particleGroupDef;
    particleGroupDef.flags =  b2_tensileParticle;
    particleGroupDef.position.Set(position.x, position.y);
    particleGroupDef.shape = &shape;
    
    ((b2ParticleSystem *)particleSystem)->CreateParticleGroup(particleGroupDef);
}


+ (void)createParticleSlinkyForSystem:(void *)particleSystem
                          position:(Vector2D)position size:(Size2D)size {
    b2PolygonShape shape;
    shape.SetAsBox(size.width * 0.5f, size.height * 0.5f);
    
    b2ParticleGroupDef particleGroupDef;
    particleGroupDef.flags =  b2_tensileParticle;
    
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

+ (void)worldStep:(CFTimeInterval)timeStep velocityIterations:(int)velocityIterations
positionIterations:(int)positionIterations {
    world->Step(timeStep, velocityIterations, positionIterations);
}

+ (void *)createEdgeBoxWithOrigin:(Vector2D)origin size:(Size2D)size {
    // create the body
    b2BodyDef bodyDef;
    bodyDef.position.Set(origin.x, origin.y);
    b2Body *body = world->CreateBody(&bodyDef);
    
    // create the edges of the box
    b2EdgeShape shape;
    
    // bottom
    shape.Set(b2Vec2(0, 0), b2Vec2(size.width, 0));
    body->CreateFixture(&shape, 0);
    
    // top
    shape.Set(b2Vec2(0, size.height), b2Vec2(size.width, size.height));
    body->CreateFixture(&shape, 0);
    
    // left
    shape.Set(b2Vec2(0, size.height), b2Vec2(0, 0));
    body->CreateFixture(&shape, 0);
    
    // right
    shape.Set(b2Vec2(size.width, size.height), b2Vec2(size.width, 0));
    body->CreateFixture(&shape, 0);
    
    return body;
}

+ (void)setGravity:(Vector2D)gravity {
    
    world->SetGravity(b2Vec2(gravity.x, gravity.y));
}

+ (void)setParticleLimitForSystem:(void *)particleSystem maxParticles:(int)maxParticles {
    ((b2ParticleSystem *)particleSystem)->SetDestructionByAge(true);
    ((b2ParticleSystem *)particleSystem)->SetMaxParticleCount(maxParticles);
}

@end
