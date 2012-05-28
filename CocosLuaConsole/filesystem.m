//
//  filesystem.m
//  CocosLua
//
//  Created by Xiliang Chen on 12-5-27.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import "filesystem.h"

#include "lauxlib.h"
#include "luamain.h"

#import "FileManager.h"

static int setDirectroy(lua_State *L) {
    const char *string = luaL_checkstring(L, -1);
    [[FileManager sharedManager] setWorkingDirectroy:[NSString stringWithUTF8String:string]];
    lua_pop(L, 1);
    return 0;
}

static const luaL_Reg methods[] = {
    {"setDirectroy", setDirectroy},
    
    {NULL, NULL},
};

int luaopen_filesystem(lua_State *L) {
    luaL_newlib(L, methods);
    return 1;
}