//  Created by ProbablyInteractive.
//  Copyright 2009 Probably Interactive. All rights reserved.

#import <Foundation/Foundation.h>
#import "lua.h"

void wax_startWithServer();
void wax_end();

lua_State *wax_currentLuaState();
void luaopen_wax(lua_State *L);