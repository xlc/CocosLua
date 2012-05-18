//
//  luamain.h
//  CocosLua
//
//  Created by Xiliang Chen on 18/05/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#ifndef CocosLua_luamain_h
#define CocosLua_luamain_h

#include "lua.h"

typedef void string_handler(const char *);
typedef void remote_callback(const char *);

int lua_main(lua_State *L);
void start_remote(string_handler h, remote_callback c);
void stop_remote(const char *reason);

#endif
