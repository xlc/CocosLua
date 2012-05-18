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

#include "wax.h"
#include "wax_helpers.h"
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

#import "LuaConsole.h"

static int print(lua_State *L);
static const char *reader(lua_State *L, void *data, size_t *size);
static int traceback (lua_State *L);

typedef struct LuaReaderInfo {
NSString *string;
BOOL done;
} LuaReaderInfo;

static LuaExecutor *sharedExecutor;

@interface LuaExecutor ()

- (void)loadLibs;
- (void)luaPrint:(NSString *)message;
- (NSError *)createErrorWithStatus:(int)status oldtop:(int)oldtop description:(NSString *)desc;

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

- (NSError *)createErrorWithStatus:(int)status oldtop:(int)oldtop description:(NSString *)desc {
    int newtop = lua_gettop(L);
    if (status == LUA_OK) {
        lua_pop(L, newtop - oldtop);
        return nil;
    }
    id errorMsg;
    if (newtop - oldtop == 1)
        errorMsg = [self pop];
    else
        errorMsg = [self popObjects:newtop - oldtop];
    if (errorMsg == nil) {
        errorMsg = @"Unknown reason";
    }
    return [NSError errorWithDomain:APP_ERROR_DOMAIN
                               code:status
                           userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                     desc, NSLocalizedDescriptionKey,
                                     errorMsg, NSLocalizedFailureReasonErrorKey,
                                     nil]];
}

#pragma mark -

- (NSError *)executeFile:(NSString *)file {
    NSString *string = [NSString stringWithFormat:@"require('%@')", file];
    return [self executeString:string];
}

- (NSError *)executeString:(NSString *)string {
    int oldtop = lua_gettop(L);
    int status = luaL_dostring(L, [string UTF8String]);
    return [self createErrorWithStatus:status
                                oldtop:oldtop
                           description:[NSString stringWithFormat:@"Fail to execute string '%@'", string]];
}

- (NSArray *)executeFunction:(NSString *)function args:(NSArray *)args error:(NSError **)error {
    int oldtop = lua_gettop(L);
    lua_getglobal(L, [function UTF8String]);
    if( !lua_isfunction(L, -1) ) {
        lua_pop(L,1);
        if (error)
            *error = [NSError errorWithDomain:APP_ERROR_DOMAIN
                                         code:1
                                     userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSString stringWithFormat:@"'%@' is not a lua function", function], NSLocalizedDescriptionKey,
                                               nil]];
        return nil;
    }
    [self pushObjects:args];
    int narg = [args count];
    int base = lua_gettop(L) - narg;  /* function index */
    lua_pushcfunction(L, traceback);  /* push traceback function */
    lua_insert(L, base);  /* put it under chunk and args */
    int status = lua_pcall(L, narg, LUA_MULTRET, base);
    lua_remove(L, base);
    int newtop = lua_gettop(L);
    if (status == LUA_OK) {  /* any result to print? */
        if (error)
            *error = nil;
        return [self popObjects:newtop - oldtop];
    } else {
        if (error)
            *error = [self createErrorWithStatus:status
                                          oldtop:oldtop
                                     description:[NSString stringWithFormat:
                                                  @"Fail to execute function '%@' with arguments: %@", function, args]];
        return nil;
    }
}

- (NSArray *)executeString:(NSString *)string error:(NSError **)error {
    int oldtop = lua_gettop(L);
    int status = luaL_dostring(L, [string UTF8String]);
    int newtop = lua_gettop(L);
    if (status == LUA_OK) {  /* any result to print? */
        if (error)
            *error = nil;
        return [self popObjects:newtop - oldtop];
    } else {
        if (error)
            *error = [self createErrorWithStatus:status
                                          oldtop:oldtop
                                     description:[NSString stringWithFormat:
                                                  @"Fail to execute sting '%@'", string]];
        return nil;
    }
    
}

#define EOFMARK "<eof>"

- (NSError *)checkString:(NSString *)string completed:(BOOL *)completed {
    const size_t marklen = (sizeof(EOFMARK)/sizeof(char) - 1);
    
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
                    error = [[[NSString alloc] initWithCString:msg encoding:NSUTF8StringEncoding] autorelease];
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

- (void)push:(id)obj {
    wax_fromInstance(L, obj);
}

- (id)pop {
    id *instancePointer = wax_copyToObjc(L, "@", -1, nil);      // TODO have handle value that is not object
    lua_pop(L, 1);
    id instance = *(id *)instancePointer;
    if (instancePointer) free(instancePointer);
    return instance;
}

- (void)pushObjects:(NSArray *)objs {
    lua_checkstack(L, [objs count]);
    for (id obj in objs) {
        [self push:obj];
    }
}

- (NSArray *)popObjects:(NSUInteger)count {
    if (count == 0)
        return nil;
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:count];
    for (int i = 0; i < count; i++) {
        id obj = [self pop];
        if (obj == nil) {
            obj = [NSNull null];
        }
        [array insertObject:obj atIndex:0];
    }
    return array;
}

#pragma mark -

- (void)luaPrint:(NSString *)message {
    NSLog(@"lua: %@", message);
    [[LuaConsole sharedConsole] appendMessage:message];
}

@end

#pragma mark -

static int print(lua_State *L) {
    NSMutableArray *tobeprint = [NSMutableArray array];
    while (lua_gettop(L) != 0) {
        lua_getglobal(L, "tostring");
        lua_insert(L, -2);
        lua_call(L, 1, 1);
        const char *str = luaL_checkstring(L, -1);
        NSString *message = [[[NSString alloc] initWithUTF8String:str] autorelease];
        [tobeprint insertObject:message atIndex:0];
        lua_pop(L, 1);
    }
    for (NSString *s in tobeprint) {
        [sharedExecutor luaPrint:s];
    }
    
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

static int traceback (lua_State *L) {
    const char *msg = lua_tostring(L, 1);
    if (msg)
        luaL_traceback(L, L, msg, 1);
    else if (!lua_isnoneornil(L, 1)) {  /* is there an error object? */
        if (!luaL_callmeta(L, 1, "__tostring"))  /* try its 'tostring' metamethod */
            lua_pushliteral(L, "(no error message)");
    }
    return 1;
}