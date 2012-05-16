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

- (NSError *)executeFile:(NSString *)file;
- (NSError *)executeString:(NSString *)string;
- (NSError *)checkString:(NSString *)string completed:(BOOL *)completed;
- (NSArray *)executeFunction:(NSString *)function args:(NSArray *)args error:(NSError **)error;
- (NSArray *)executeString:(NSString *)string error:(NSError **)error;

- (void)push:(id)obj;
- (id)pop;
- (void)pushObjects:(NSArray *)objs;
- (NSArray *)popObjects:(NSUInteger)count;

@end
