//
//  LuaExecutor.m
//  CocosLua
//
//  Created by Xiliang Chen on 12-5-13.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import "LuaExecutor.h"

#include "lauxlib.h"
#include "lualib.h"

#include "wax_class.h"
#include "wax_instance.h"
#include "wax_struct.h"
#include "wax_CGContext.h"
#include "wax_CGTransform.h"
#include "wax_http.h"
#include "wax_filesystem.h"
#include "wax_json.h"
#include "wax_sqlite.h"
#include "wax_xml.h"

#include "wax.h"

char *ScriptSearchPath = NULL;

static LuaExecutor *sharedExecutor;

@interface LuaExecutor ()

- (void)loadLibs;

@end

@implementation LuaExecutor

@synthesize state = _state;

+ (void)initialize {
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *path = [NSString stringWithFormat:@"%@/?.lua;%@/?/init.lua;%@/Scripts/?.lua;%@/Scripts/?/init.lua", bundlePath, bundlePath, bundlePath, bundlePath];
    ScriptSearchPath = malloc(sizeof(char) * [path length] + 1);
    [path getCString:ScriptSearchPath maxLength:[path length] + 1 encoding:NSASCIIStringEncoding];
    [CCLabelTTF class]; // pull cocos2d runtime
}

+ (LuaExecutor *)sharedExecutor {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedExecutor = [[LuaExecutor alloc] init];
    });
    return sharedExecutor;
}

- (id)init
{
    self = [super init];
    if (self) {
        wax_setup();
        _state = wax_currentLuaState();
        [self loadLibs];
    }
    return self;
}

- (void)dealloc
{
    lua_close(_state);
    
    [super dealloc];
}

#pragma mark -

- (void)loadLibs {
    // load std libs
//    luaL_openlibs(_state);
    
    // load c libs
//    luaopen_wax_class(_state);
//    luaopen_wax_instance(_state);
//    luaopen_wax_struct(_state);
    luaopen_wax_CGContext(_state);
    luaopen_wax_CGTransform(_state);
    luaopen_wax_http(_state);
    luaopen_wax_filesystem(_state);
    luaopen_wax_json(_state);
    luaopen_wax_sqlite(_state);
    luaopen_wax_xml(_state);
    
    // load lua libs
    MASSERT_ERROR([self loadFile:@"wax"]);
    MASSERT_ERROR([self loadFile:@"init"]);
}

#pragma mark -

- (NSError *)loadFile:(NSString *)file {
    NSString *string = [NSString stringWithFormat:@"require('%@')", file];
    return [self loadString:string];
}

- (NSError *)loadString:(NSString *)string {
    int ret = luaL_dostring(_state, [string UTF8String]);
    if (ret) {
        NSString *errorStr = [NSString stringWithCString:lua_tostring(_state,-1) encoding:NSUTF8StringEncoding];
        return [NSError errorWithDomain:APP_ERROR_DOMAIN
                                   code:ret
                               userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                         @"Failed to load script", NSLocalizedDescriptionKey,
                                         errorStr, NSLocalizedFailureReasonErrorKey
                                         , nil]];
    }
    return nil;
}

@end
