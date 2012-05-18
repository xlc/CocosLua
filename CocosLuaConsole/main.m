//
//  main.m
//  CocosLuaConsole
//
//  Created by Xiliang Chen on 18/05/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#include "lauxlib.h"

#include "luamain.h"


int main (int argc, const char * argv[])
{
    @autoreleasepool {
        
        lua_State *L = luaL_newstate();
        assert(L != NULL);
        lua_main(L);
        lua_close(L);
    }
    return 0;
}



