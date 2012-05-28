//
//  luamain.c
//  CocosLua
//
//  Created by Xiliang Chen on 18/05/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

/*
 ** $Id: lua.c,v 1.203 2011/12/12 16:34:03 roberto Exp $
 ** Lua stand-alone interpreter
 ** See Copyright Notice in lua.h
 */

#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

#include "luamain.h"

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

#include "browser.h"
#include "filesystem.h"

#define LUA_PROMPT		"> "
#define LUA_PROMPT2		">> "
#define LUA_PROGNAME		"lua"
#define LUA_MAXINPUT		512

/*
 ** lua_readline defines how to show a prompt and then read a line from
 ** the standard input.
 ** lua_saveline defines how to "save" a read line in a "history".
 ** lua_freeline defines how to free a line read by lua_readline.
 */
#undef LUA_USE_READLINE // readline does not like xcode debug console
#if defined(LUA_USE_READLINE)

#include <stdio.h>
#include <readline/readline.h>
#include <readline/history.h>
#define lua_readline(L,b,p)     ((void)L, ((b)=readline(p)) != NULL)
#define lua_saveline(L,idx) \
if (lua_rawlen(L,idx) > 0)  /* non-empty line? */ \
add_history(lua_tostring(L, idx));  /* add it to history */
#define lua_freeline(L,b)       ((void)L, free(b))

#elif !defined(lua_readline)

#define lua_readline(L,b,p)     \
((void)L, fputs(p, stdout), fflush(stdout),  /* show prompt */ \
fgets(b, LUA_MAXINPUT, stdin) != NULL)  /* get line */
#define lua_saveline(L,idx)     { (void)L; (void)idx; }
#define lua_freeline(L,b)       { (void)L; (void)b; }

#endif

#define LOCAL_NAME "local"
#define REMOTE_NAME "remote"

static lua_State *globalL = NULL;
static const char *progname = LUA_PROGNAME;
static int remote_enabled = 0;
static string_handler *handler;
static remote_callback *callback;

static void lstop (lua_State *L, lua_Debug *ar) {
    (void)ar;  /* unused arg. */
    lua_sethook(L, NULL, 0, 0);
    luaL_error(L, "interrupted!");
}

static void laction (int i) {
    signal(i, SIG_DFL); /* if another SIGINT happens before lstop,
                         terminate process (default action) */
    lua_sethook(globalL, lstop, LUA_MASKCALL | LUA_MASKRET | LUA_MASKCOUNT, 1);
}

static void l_message (const char *pname, const char *msg) {
    if (pname) luai_writestringerror("%s: ", pname);
    luai_writestringerror("%s\n", msg);
}

static int report (lua_State *L, int status) {
    if (status != LUA_OK && !lua_isnil(L, -1)) {
        const char *msg = lua_tostring(L, -1);
        if (msg == NULL) msg = "(error object is not a string)";
        l_message(progname, msg);
        lua_pop(L, 1);
        /* force a complete garbage collection in case of errors */
        lua_gc(L, LUA_GCCOLLECT, 0);
    }
    return status;
}

/* the next function is called unprotected, so it must avoid errors */
static void finalreport (lua_State *L, int status) {
    if (status != LUA_OK) {
        const char *msg = (lua_type(L, -1) == LUA_TSTRING) ? lua_tostring(L, -1)
        : NULL;
        if (msg == NULL) msg = "(error object is not a string)";
        l_message(progname, msg);
        lua_pop(L, 1);
    }
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


static int docall (lua_State *L, int narg, int nres) {
    int status;
    int base = lua_gettop(L) - narg;  /* function index */
    lua_pushcfunction(L, traceback);  /* push traceback function */
    lua_insert(L, base);  /* put it under chunk and args */
    globalL = L;  /* to be available to 'laction' */
    signal(SIGINT, laction);
    status = lua_pcall(L, narg, nres, base);
    signal(SIGINT, SIG_DFL);
    lua_remove(L, base);  /* remove traceback function */
    return status;
}

static const char *get_prompt (lua_State *L, int firstline) {
    const char *p;
    if (remote_enabled) {
        p = (firstline ? REMOTE_NAME LUA_PROMPT : REMOTE_NAME LUA_PROMPT2);
    } else {
        p = (firstline ? LOCAL_NAME LUA_PROMPT : LOCAL_NAME LUA_PROMPT2);
    }
    return p;
}

static void print_version (void) {
    luai_writestring(LUA_COPYRIGHT, strlen(LUA_COPYRIGHT));
    luai_writeline();
}

/* mark in error messages for incomplete statements */
#define EOFMARK		"<eof>"
#define marklen		(sizeof(EOFMARK)/sizeof(char) - 1)

static int incomplete (lua_State *L, int status) {
    if (status == LUA_ERRSYNTAX) {
        size_t lmsg;
        const char *msg = lua_tolstring(L, -1, &lmsg);
        if (lmsg >= marklen && strcmp(msg + lmsg - marklen, EOFMARK) == 0) {
            lua_pop(L, 1);
            return 1;
        }
    }
    return 0;  /* else... */
}

static int pushline (lua_State *L, int firstline) {
    char buffer[LUA_MAXINPUT];
    char *b = buffer;
    size_t l;
    const char *prmt = get_prompt(L, firstline);
    if (lua_readline(L, b, prmt) == 0)
        return 0;  /* no input */
    l = strlen(b);
    if (l > 0 && b[l-1] == '\n')  /* line ends with newline? */
        b[l-1] = '\0';  /* remove it */
    if (firstline && b[0] == '=')  /* first line starts with `=' ? */
        lua_pushfstring(L, "return %s", b+1);  /* change it to `return' */
    else
        lua_pushstring(L, b);
    lua_freeline(L, b);
    return 1;
}


static int loadline (lua_State *L) {
    int status = 0;
    lua_settop(L, 0);
    if (!pushline(L, 1)) {
        if (remote_enabled) {
            stop_remote("disconnected by user");
            if (!pushline(L, 1)) {  // get local message
                return -1;  // still no input
            }
        } else {
            return -1;  /* no input */
        }
    }
    if (remote_enabled) {
        const char *line = lua_tostring(L, 1);
        handler(line);
    } else {
        for (;;) {  /* repeat until gets a complete line */
            size_t l;
            const char *line = lua_tolstring(L, 1, &l);
            status = luaL_loadbuffer(L, line, l, "=stdin");
            if (!incomplete(L, status)) break;  /* cannot try to add lines? */
            if (!pushline(L, 0))  /* no more input? */
                return -1;
            lua_pushliteral(L, "\n");  /* add a new line... */
            lua_insert(L, -2);  /* ...between the two lines */
            lua_concat(L, 3);  /* join them */
        }
    }
    lua_saveline(L, 1);
    lua_remove(L, 1);  /* remove line */
    return status;
}

static void dotty (lua_State *L) {
    int status;
    const char *oldprogname = progname;
    progname = NULL;
    print_version();
    while ((status = loadline(L)) != -1) {
        if (status == LUA_OK) status = docall(L, 0, LUA_MULTRET);
        report(L, status);
        if (status == LUA_OK && lua_gettop(L) > 0) {  /* any result to print? */
            luaL_checkstack(L, LUA_MINSTACK, "too many results to print");
            lua_getglobal(L, "print");
            lua_insert(L, 1);
            if (lua_pcall(L, lua_gettop(L)-1, 0, 0) != LUA_OK)
                l_message(progname, lua_pushfstring(L,
                                                    "error calling " LUA_QL("print") " (%s)",
                                                    lua_tostring(L, -1)));
        }
    }
    lua_settop(L, 0);  /* clear stack */
    luai_writeline();
    progname = oldprogname;
}

static int pmain (lua_State *L) {
    
    /* open standard libraries */
    luaL_checkversion(L);
    lua_gc(L, LUA_GCSTOP, 0);  /* stop collector during initialization */
    luaL_openlibs(L);  /* open libraries */
    
    luaL_requiref(L, "browser", luaopen_browser, 1);    // load modules
    lua_getglobal(L, "browser");
    lua_getfield(L, -1, "connect");
    lua_setglobal(L, "connect");
    lua_pop(L, 1);
    
    luaL_requiref(L, "filesystem", luaopen_filesystem, 1);    // load modules
    lua_getglobal(L, "filesystem");
    lua_setglobal(L, "fs");
    
    lua_gc(L, LUA_GCRESTART, 0);
    dotty(L);
    lua_pushboolean(L, 1);  /* signal no errors */
    return 1;
}

int lua_main(lua_State *L) {
    int status, result;
    /* call 'pmain' in protected mode */
    lua_pushcfunction(L, &pmain);
    status = lua_pcall(L, 0, 1, 0);
    result = lua_toboolean(L, -1);  /* get result */
    finalreport(L, status);
    lua_pop(L, 1);
    return (result && status == LUA_OK) ? EXIT_SUCCESS : EXIT_FAILURE;
}

void start_remote(string_handler h, remote_callback c) {
    assert(h != NULL);
    handler = h;
    callback = c;
    remote_enabled = 1;
}

void stop_remote(const char *reason) {
    handler = NULL;
    remote_enabled = 0;
    if (callback) {
        callback(reason);
    }
}