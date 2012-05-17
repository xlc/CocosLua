//
//  LuaServer.m
//  CocosLua
//
//  Created by Xiliang Chen on 12-5-17.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import "LuaServer.h"

#import "TCPServer.h"

static LuaServer *sharedServer;

@implementation LuaServer {
    TCPServer *_server;
}

+ (LuaServer *)sharedServer {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedServer = [[LuaServer alloc] init];
    });
    return sharedServer;
}

- (id)init
{
    self = [super init];
    if (self) {
        
    }
    return self;
}

@end
