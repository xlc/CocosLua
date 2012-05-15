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

#import "LuaConsole.h"

static int print(lua_State *L);
static const char *reader(lua_State *L, void *data, size_t *size);

typedef struct LuaReaderInfo {
NSString *string;
BOOL done;
} LuaReaderInfo;

static LuaExecutor *sharedExecutor;

@interface LuaExecutor ()

- (void)loadLibs;
- (void)luaPrint:(NSString *)message;

@end

@implementation LuaExecutor

@synthesize state = L;

+ (LuaExecutor *)sharedExecutor {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedExecutor = [[LuaExecutor alloc] init];
        [sharedExecutor loadLibs];
    });
    return sharedExecutor;
}

- (id)init
{
    self = [super init];
    if (self) {
        L = wax_currentLuaState();
    }
    return self;
}

- (void)dealloc
{
    lua_close(L);
    
    [super dealloc];
}

#pragma mark -

- (void)loadLibs {
    [[NSFileManager defaultManager] changeCurrentDirectoryPath:[[NSBundle mainBundle] bundlePath]];
    
    lua_gc(L, LUA_GCSTOP, 0);  /* stop collector during initialization */
    
    // load std libs
    luaL_openlibs(L);
    
    // load c libs
    luaopen_wax(L);
    luaopen_wax_CGContext(L);
    luaopen_wax_CGTransform(L);
    luaopen_wax_http(L);
    luaopen_wax_filesystem(L);
    luaopen_wax_json(L);
    luaopen_wax_sqlite(L);
    luaopen_wax_xml(L);
    
    // load custom functinos
    lua_register(L, "print", print);
    
    // load lua libs
    MASSERT_NOERR([self executeFile:@"wax"]);
    MASSERT_NOERR([self executeFile:@"init"]);
    
    lua_gc(L, LUA_GCRESTART, 0);
}

#pragma mark -

- (NSError *)executeFile:(NSString *)file {
    NSString *string = [NSString stringWithFormat:@"require('%@')", file];
    return [self executeString:string];
}

- (NSError *)executeString:(NSString *)string {
    int ret = luaL_dostring(L, [string UTF8String]);
    if (ret) {
        NSString *errorStr = [NSString stringWithCString:lua_tostring(L,-1) encoding:NSUTF8StringEncoding];
        return [NSError errorWithDomain:APP_ERROR_DOMAIN
                                   code:ret
                               userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                         @"Failed to load script", NSLocalizedDescriptionKey,
                                         errorStr, NSLocalizedFailureReasonErrorKey,
                                         nil]];
    }
    return nil;
}

#define EOFMARK		"<eof>"
#define marklen		(sizeof(EOFMARK)/sizeof(char) - 1)

- (NSError *)checkString:(NSString *)string completed:(BOOL *)completed {
    LuaReaderInfo info = {string, NO};
    int status = lua_load(L, reader, (void *)&info, [string UTF8String], NULL);
    switch (status) {
        case LUA_OK:
            *completed = YES;
            return nil;
        case LUA_ERRSYNTAX:
        {
            size_t lmsg;
            const char *msg = lua_tolstring(L, -1, &lmsg);
            if (lmsg >= marklen && strcmp(msg + lmsg - marklen, EOFMARK) == 0) {
                lua_pop(L, 1);
                *completed = NO;
                return nil;
            } // else
        }
        default:
        {
            *completed = YES;
            NSString *error = @"Unknown error";
            if (!lua_isnil(L, -1)) {
                const char *msg = lua_tostring(L, -1);
                if (msg) {
                    error = [[NSString alloc] initWithCString:msg encoding:NSUTF8StringEncoding];
                }
                lua_pop(L, 1);
                /* force a complete garbage collection in case of errors */
                lua_gc(L, LUA_GCCOLLECT, 0);
            }
            return [NSError errorWithDomain:APP_ERROR_DOMAIN
                                       code:status
                                   userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                             @"Checking string error", NSLocalizedDescriptionKey,
                                             error, NSLocalizedFailureReasonErrorKey,
                                             nil]];
        }
    }
}

#pragma mark -

- (void)luaPrint:(NSString *)message {
    NSLog(@"lua: %@", message);
    [[LuaConsole sharedConsole] appendMessage:message];
}

@end

static int print(lua_State *L) {
    const char *str = luaL_checkstring(L, -1);
    NSString *message = [[[NSString alloc] initWithCString:str encoding:NSUTF8StringEncoding] autorelease];
    [sharedExecutor luaPrint:message];
    return 0;
}

static const char *reader(lua_State *L, void *data, size_t *size) {
    LuaReaderInfo *info = (LuaReaderInfo *)data;
    if (info->done) {
        *size = 0;
        return NULL;
    }
    info->done = YES;
    NSString *string = info->string;
    *size = [string lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    return [string UTF8String];
}