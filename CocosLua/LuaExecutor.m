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

static int print(lua_State *L);

static LuaExecutor *sharedExecutor;

@interface LuaExecutor ()

- (void)loadLibs;
- (void)luaPrint:(NSString *)message;

@end

@implementation LuaExecutor

@synthesize state = _state;

+ (LuaExecutor *)sharedExecutor {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedExecutor = [[LuaExecutor alloc] init];
    });
    static dispatch_once_t onceToken2;
    dispatch_once(&onceToken2, ^{
        [sharedExecutor loadLibs];
    });
    return sharedExecutor;
}

- (id)init
{
    self = [super init];
    if (self) {
        _state = wax_currentLuaState();
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
    [[NSFileManager defaultManager] changeCurrentDirectoryPath:[[NSBundle mainBundle] bundlePath]];
    
    // load std libs
    luaL_openlibs(_state);
    
    // load c libs
    luaopen_wax(_state);
    luaopen_wax_CGContext(_state);
    luaopen_wax_CGTransform(_state);
    luaopen_wax_http(_state);
    luaopen_wax_filesystem(_state);
    luaopen_wax_json(_state);
    luaopen_wax_sqlite(_state);
    luaopen_wax_xml(_state);
    
    // load custom functinos
    lua_register(_state, "print", print);
    
    // load lua libs
    MASSERT_NOERR([self executeFile:@"wax"]);
    MASSERT_NOERR([self executeFile:@"init"]);
    
}

#pragma mark -

- (NSError *)executeFile:(NSString *)file {
    NSString *string = [NSString stringWithFormat:@"require('%@')", file];
    return [self executeString:string];
}

- (NSError *)executeString:(NSString *)string {
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

#pragma mark -

- (void)luaPrint:(NSString *)message {
    NSLog(@"lua: %@", message);
}

@end

static int print(lua_State *L) {
    const char *str = luaL_checkstring(L, -1);
    NSString *message = [[[NSString alloc] initWithCString:str encoding:NSUTF8StringEncoding] autorelease];
    [sharedExecutor luaPrint:message];
    return 0;
}