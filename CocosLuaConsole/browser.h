//
//  browser.h
//  CocosLua
//
//  Created by Xiliang Chen on 18/05/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#include "lua.h"

@class LuaClient;

int luaopen_browser(lua_State *L);

LuaClient *get_client(void);