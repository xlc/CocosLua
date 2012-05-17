//
//  ObjLua.m
//  Lua
//
//  Created by ProbablyInteractive on 5/27/09.
//  Copyright 2009 Probably Interactive. All rights reserved.
//

#import "wax.h"
#import "wax_class.h"
#import "wax_instance.h"
#import "wax_struct.h"
#import "wax_helpers.h"

#import "lauxlib.h"
#import "lobject.h"
#import "lualib.h"

static void addGlobals(lua_State *L);
static int tolua(lua_State *L);
static int toobjc(lua_State *L);
static int objcDebug(lua_State *L);

static lua_State *currentL;
lua_State *wax_currentLuaState() {
    
    if (!currentL) 
        currentL = luaL_newstate();
    
    return currentL;
}

void uncaughtExceptionHandler(NSException *e) {
    NSLog(@"ERROR: Uncaught exception %@", [e description]);
    lua_State *L = wax_currentLuaState();
    
    if (L) {
        wax_getStackTrace(L);
        const char *stackTrace = luaL_checkstring(L, -1);
        NSLog(@"%s", stackTrace);
        lua_pop(L, -1); // remove the stackTrace
    }
}

int wax_panic(lua_State *L) {
	printf("Lua panicked and quit: %s\n", luaL_checkstring(L, -1));
    wax_getStackTrace(L);
    const char *stackTrace = luaL_checkstring(L, -1);
    NSLog(@"%s", stackTrace);
    lua_pop(L, -1); // remove the stackTrace
    return 0;
}

lua_CFunction lua_atpanic (lua_State *L, lua_CFunction panicf);

void luaopen_wax(lua_State *L) {
    NSSetUncaughtExceptionHandler(uncaughtExceptionHandler);
    lua_atpanic(L, wax_panic);
    
    luaopen_wax_class(L);
    luaopen_wax_instance(L);
    luaopen_wax_struct(L);
    
    addGlobals(L);
}

void wax_end() {
    if (currentL) {
        lua_close(currentL);
        currentL = NULL;
    }
}

static void addGlobals(lua_State *L) {
    lua_getglobal(L, "wax");
    
    lua_pushstring(L, [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] UTF8String]);
    lua_setfield(L, -2, "appVersion"); 
    
#ifdef DEBUG
    lua_pushboolean(L, YES);
    lua_setfield(L, -2, "isDebug");
#endif
    
    lua_pop(L, 1);
    
    lua_pushcfunction(L, tolua);
    lua_setglobal(L, "tolua");
    
    lua_pushcfunction(L, toobjc);
    lua_setglobal(L, "toobjc");
    
    lua_pushstring(L, [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] UTF8String]);
    lua_setglobal(L, "NSDocumentDirectory");
    
    lua_pushstring(L, [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0] UTF8String]);
    lua_setglobal(L, "NSLibraryDirectory");
    
    NSString *cachePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSError *error;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:cachePath withIntermediateDirectories:YES attributes: nil error:&error]) {
        NSLog(@"fail to create cache directory with error: %@", error);
    }
    
    lua_pushstring(L, [cachePath UTF8String]);
    lua_setglobal(L, "NSCacheDirectory");
    
}

static int tolua(lua_State *L) {
    if (lua_isuserdata(L, 1)) { // If it's not userdata... it's already lua!
        wax_instance_userdata *instanceUserdata = (wax_instance_userdata *)luaL_checkudata(L, 1, WAX_INSTANCE_METATABLE_NAME);
        wax_fromInstance(L, instanceUserdata->instance);
    }
    
    return 1;
}

static int toobjc(lua_State *L) {
    id *instancePointer = wax_copyToObjc(L, "@", 1, nil);
    id instance = *(id *)instancePointer;
    
    wax_instance_create(L, instance, NO);
    
    if (instancePointer) free(instancePointer);
    
    return 1;
}