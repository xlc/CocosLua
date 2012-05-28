//
//  browser.m
//  CocosLua
//
//  Created by Xiliang Chen on 18/05/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#include "browser.h"

#include "lauxlib.h"
#include "luamain.h"

#import "BonjourBrowser.h"
#import "LuaClient.h"
#import "MessagePacket.h"

static BonjourBrowser *browser;
static LuaClient *client;

static void send_string(const char *str) {
    if (client.connected) {
        [client sendPacket:[MessagePacket packetWithType:MessageTypeString content:[NSString stringWithUTF8String:str]]];
    } else {
        stop_remote("disconnected from server");
    }
}

static void close_connection(const char *reason) {
    NSLog(@"Connection closed: %s", reason);
    [client close];
    [client release];
    client = nil;
}

static BOOL createClient(void) {
    if (client.connected) {
        return YES;
    }
    [client release];
    client = [[LuaClient alloc] initWithNetService:browser.server];
    if (!client) {
        return NO;
    }
    start_remote(send_string, close_connection);
    return YES;
}

static int start(lua_State *L) {
    if (!browser) {
        browser = [[BonjourBrowser alloc] init];
    }
    [browser start];
    return 0;
}

static int stop(lua_State *L) {
    [browser stop];
    stop_remote("stop by user");
    return 0;
}

static int connect(lua_State *L) {
    if (!browser) {
        start(L);
    }
    BOOL done;
    if (lua_isnumber(L, -1)) {
        done = [browser waitForTimeInterview:lua_tonumber(L, -1)];
    } else {
        done = [browser wait];
    }
    if (done && createClient()) {
        lua_pushboolean(L, 1);
    } else {
        lua_pushboolean(L, 0);
    }
    return 1;
}

static int tryconnect(lua_State *L) {
    if (!browser) {
        start(L);
    }
    if (browser.server && createClient()) {
        lua_pushboolean(L, 1);
    } else {
        lua_pushboolean(L, 0);
    }
    return 1;
}

static int printerror(lua_State *L) {
    lua_getglobal(L, "print");
    if (browser.errorDict) {
        lua_pushstring(L, [[browser.errorDict description] UTF8String]);
    } else {
        lua_pushstring(L, "no error");
    }
    lua_call(L, 1, 0);
    return 0;
}


static const luaL_Reg methods[] = {
    {"start", start},
    {"stop", stop},
    {"connect", connect},
    {"tryconnect", tryconnect},
    {"printerror", printerror},
    {NULL, NULL},
};

int luaopen_browser(lua_State *L) {
    luaL_newlib(L, methods);
    return 1;
}

LuaClient *get_client() {
    return client;
}