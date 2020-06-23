/*
 * 2019.12.4
 * Project Tooru
 * gametracer lua mod
 *
 */

#include "gt/gt.h"
#include "tooru.h"
#include <stdlib.h>
#include <stdio.h>
#include <assert.h>

/* Find all nash eq with gnm in gametracer.
 *
 * Return a list of nash eq, each nash eq is also a list indexed by
 * player-action index. A tag "NASH_EQ" is include for each eq list.
 *
 * Lua_Cfun(G)
 *
 * <G> Game info */
static int gnm_ex(lua_State *L)
{
    int pn;
    int *lan;
    int i, j, k;
    int /*good,*/ ret;
    int /*total,*/ eq_l;
    /* char msg[100]; */
    double *gt_payoff, *payoff_mtx;
    long long payoff_l, outcome_n;
    double *eqs;
    int eq_num;
    /* long long tmp; */
    struct Game_Info *G;

    G = (struct Game_Info *)luaL_checkudata(L, 1, TOORU_EVOSIM_UDN_GAMEINFO);
    outcome_n = G->ary_hex[G->players_amount - 1] * G->local_actions_amount[G->players_amount - 1];
    payoff_l = outcome_n * G->players_amount;
    if (payoff_l > INT_MAX)
    {
        lua_pushnil(L);
        lua_pushliteral(L, "gametracer only support i32 int");
        return 2;
    }

    /* gt's payoff array is different to ours */
    gt_payoff = (double *)malloc(sizeof(double) * (size_t)payoff_l);
    pn = (int)G->players_amount;
    lan = (int *)malloc((size_t)pn * sizeof(int));
    payoff_mtx = G->pmtx;
    k = 0;
    for (i = 0; i < pn; i++)
    {
        lan[i] = (int)G->local_actions_amount[i];
        for (j = 0; j < (int)outcome_n; j++)
        {
            gt_payoff[k] = payoff_mtx[i + (j * pn)];
            k += 1;
        }
    }
    assert(k == (int)payoff_l);

    /* used for not with G
    tmp = luaL_checkinteger(L, 1);
    if (tmp > INT_MAX)
    {
        lua_pushnil(L);
        lua_pushliteral(L, "gametracer only support i32 int");
        return 2;
    }
    pn = (int)tmp;
    luaL_argcheck(L, pn > 1, 1, "invalid players number");
    luaL_checktype(L, 2, LUA_TTABLE);
    if (pn != luaL_len(L, 2))
        luaL_error(L, "lgt error: players number not eq with players actions list length"); */
    /* used for not with G
    total = pn;
    total = (int)G->ary_hex[pn - 1] * lan[pn - 1] * pn; */
    eq_l = (int)G->mixed_len;
    /* used for not with G
    for (i = 0; i < pn; i++)
    {
        lua_geti(L, 2, i + 1);
        tmp = lua_tointegerx(L, -1, &good);
        if (tmp > INT_MAX)
        {
            free(lan);
            lua_pushnil(L);
            lua_pushliteral(L, "gametracer only support i32 int");
            return 2;
        }
        lan[i] = (int)tmp;
        if (!good || lan[i] < 1)
        {
            sprintf(msg, "need a list of +int, but index %d is not", i + 1);
            luaL_argerror(L, 2, msg);
        }
        lua_pop(L, 1);
        total *= lan[i];
        eq_l += lan[i];
    }
    luaL_checktype(L, 3, LUA_TTABLE);
    if (total != luaL_len(L, 3))
        luaL_error(L, "lgt error: payoff mtx's length is invalid with players' info");
    payoff_mtx = (double *)malloc(sizeof(double) * total);
    for (i = 0; i < total; i++)
    {
        lua_geti(L, 3, i + 1);
        payoff_mtx[i] = lua_tonumberx(L, -1, &good);
        if (!good)
        {
            sprintf(msg, "need a list of number, but index %d is not", i + 1);
            luaL_argerror(L, 3, msg);
        }
        lua_pop(L, 1);
    } */

    eqs = gt_gnm_new(pn, lan, gt_payoff, &eq_num);
    if (eq_num < 0)
    {
        lua_pushnil(L);
        lua_pushstring(L, gt_error(eq_num));
        ret = 2;
    }
    else
    {
        lua_createtable(L, eq_num, 0);
        for (i = 0; i < eq_num; i++)
        {
            lua_createtable(L, eq_l, 0);
            lua_pushliteral(L, "NASH_EQ");
            lua_setfield(L, -2, "TAG");
            for (j = 0; j < eq_l; j++)
            {
                lua_pushnumber(L, eqs[i * eq_l + j]);
                lua_seti(L, -2, j + 1);
            }
            lua_seti(L, -2, i + 1);
        }
        ret = 1;
    }

    free(eqs);
    /* used for not with G
    free(payoff_mtx); */
    free(gt_payoff);
    free(lan);
    return ret;
}

/* Find all nash eq with ipa in gametracer.
 *
 * Return a nash eq, nash eq is a list indexed by
 * player-action index. A tag "NASH_EQ" is include for eq list.
 *
 * Lua_Cfun(G)
 *
 * <G> Game info */
static int ipa_ex(lua_State *L)
{
    int pn;
    int *lan;
    int i, j, k;
    int ret;
    int eq_l;
    double *gt_payoff, *payoff_mtx;
    long long payoff_l, outcome_n;
    double *eqs;
    struct Game_Info *G;

    G = (struct Game_Info *)luaL_checkudata(L, 1, TOORU_EVOSIM_UDN_GAMEINFO);
    outcome_n = G->ary_hex[G->players_amount - 1] * G->local_actions_amount[G->players_amount - 1];
    payoff_l = outcome_n * G->players_amount;
    if (payoff_l > INT_MAX)
    {
        lua_pushnil(L);
        lua_pushliteral(L, "gametracer only support i32 int");
        return 2;
    }

    /* gt's payoff array is different to ours */
    gt_payoff = (double *)malloc(sizeof(double) * (size_t)payoff_l);
    pn = (int)G->players_amount;
    lan = (int *)malloc((size_t)pn * sizeof(int));
    payoff_mtx = G->pmtx;
    k = 0;
    for (i = 0; i < pn; i++)
    {
        lan[i] = (int)G->local_actions_amount[i];
        for (j = 0; j < (int)outcome_n; j++)
        {
            gt_payoff[k] = payoff_mtx[i + (j * pn)];
            k += 1;
        }
    }
    assert(k == (int)payoff_l);

    eq_l = (int)G->mixed_len;
    eqs = (double *)malloc(sizeof(double) * (size_t)eq_l);
    /* i believe ipa only return one nash eq */
    k = gt_ipa(pn, lan, gt_payoff, eqs);

    if (k < 0)
    {
        lua_pushnil(L);
        lua_pushstring(L, gt_error(k));
        ret = 2;
    }
    else
    {
        lua_createtable(L, 1, 0);
        lua_createtable(L, eq_l, 0);
        lua_pushliteral(L, "NASH_EQ");
        lua_setfield(L, -2, "TAG");
        for (j = 0; j < eq_l; j++)
        {
            lua_pushnumber(L, eqs[j]);
            lua_seti(L, -2, j + 1);
        }
        lua_seti(L, -2, 1);
        ret = 1;
    }

    free(eqs);
    free(gt_payoff);
    free(lan);
    return ret;
}

static const luaL_Reg LGT[] = {
    {"gnm", gnm_ex},
    {"ipa", ipa_ex},
    {NULL, NULL}};

TOORU_EXPORT int luaopen_libtooru_lgt(lua_State *L)
{
    luaL_newlib(L, LGT);
    return 1;
}