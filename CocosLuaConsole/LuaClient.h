//
//  LuaClient.h
//  CocosLua
//
//  Created by Xiliang Chen on 12-5-18.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MessagePacket;

@interface LuaClient : NSObject

@property (nonatomic, readonly) BOOL connected;

- (id)initWithNetService:(NSNetService *)service;

- (void)sendPacket:(MessagePacket *)packet;

- (void)close;

@end
