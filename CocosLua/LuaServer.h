//
//  LuaServer.h
//  CocosLua
//
//  Created by Xiliang Chen on 12-5-17.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LuaServer : NSObject

@property (nonatomic, readonly) BOOL started;
@property (nonatomic, readonly) BOOL connected;

+ (LuaServer *)sharedServer;

- (BOOL)start;
- (void)stop;

@end
