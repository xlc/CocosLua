//
//  LuaExecutor.h
//  CocosLua
//
//  Created by Xiliang Chen on 12-5-13.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#include "lua.h"

@interface LuaExecutor : NSObject

@property (nonatomic, readonly) lua_State *state;

+ (LuaExecutor *)sharedExecutor;

- (NSError *)loadFile:(NSString *)file;
- (NSError *)loadString:(NSString *)string;

@end
