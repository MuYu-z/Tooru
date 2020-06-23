/*
 * 2019.5.19
 * Project Tooru
 * libtooru.so header for lua mod
 *
 */

#ifndef TOORU_H
#define TOORU_H

#ifdef _WIN32
#define TOORU_EXPORT __declspec(dllexport)
#else
#define TOORU_EXPORT
#endif

#include "lua54/lauxlib.h"
#include "lua54/lua.h"

/* here some export functions to Lua */
TOORU_EXPORT int luaopen_libtooru_evosim(lua_State *L);
TOORU_EXPORT int luaopen_libtooru_lgt(lua_State *L);
TOORU_EXPORT int luaopen_libtooru_others(lua_State *L);

/* Game_Info contains some necessary infomation about a game needed by C */
struct Game_Info
{
  long long *local_actions_amount;
  long long *ary_hex;
  long long players_amount;
  double *pmtx;
  long long mixed_len;
};

/* define userdata's name */
#define TOORU_EVOSIM_UDN_GAMEINFO "tooru_others_gameinfo"

/* define some epsilon */
#define PAYOFF_EPSILON 1e-3
#define MIXED_EPSILON 1e-3

#endif