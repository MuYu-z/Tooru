/* 2019.7.16
 * Project Tooru
 * libtooru.so others calculations (br & pf), handle game info */

#include "tooru.h"
#include <assert.h>
#include <float.h>
#include <stdlib.h>
#include <string.h>

extern int f_eq(double f1, double f2, double max_diff, double max_rel_diff);
extern int lu_number_list_array(lua_State *L, int idx, const long long s,
                                const long long l, double *ret);
extern int lu_integer_list_array(lua_State *L, int idx, const long long s,
                                 const long long l, long long *ret);
extern void lu_number_array_list(lua_State *L, const double *arr,
                                 const long long l);
extern void lu_integer_array_list(lua_State *L, const long long *arr,
                                  const long long l);

/* u find mixed or not */
static void *outcome_from_lua_whatever_mixed_or_not_new(lua_State *L,
                                                        struct Game_Info *G,
                                                        int idx,
                                                        int *is_mixed) {
  long long pn;
  long long *lan;
  /* used for mixed */
  double *mixed, *mixed_pro;
  long long l;
  /* used for not mixed */
  long long *outcome;
  int good;

  /* simple check for outcome */
  lan = G->local_actions_amount;
  pn = G->players_amount;
  luaL_checktype(L, idx, LUA_TTABLE);
  luaL_argcheck(L, luaL_len(L, idx) == pn, idx,
                "outcome's length is not player amount");

  /* get 1st element, find the outcome is mixed or not */
  lua_geti(L, idx, 1);
  switch (lua_type(L, -1)) {
  case LUA_TTABLE:
    /* get mixed outcome to c */
    mixed = (double *)malloc(G->mixed_len * sizeof(double));
    mixed_pro = mixed;
    for (long long i = 0; i < pn; i++) {
      lua_geti(L, 2, i + 1);
      /* ...;-1=pi_mixed; */
      l = luaL_len(L, -1);
      luaL_argcheck(
          L, l == lan[i], 2,
          "player's mixed choice's length is not her local action amount");
      luaL_argcheck(L, lu_number_list_array(L, -1, 1, l, mixed_pro), 2,
                    "player's mixed choice is invalid, "
                    "some value is not a number");
      lua_pop(L, 1);
      /* ...; */
      mixed_pro += l;
    }
    assert(mixed == mixed_pro - G->mixed_len);
    *is_mixed = 1;
    lua_pop(L, 1);
    return (void *)mixed;

  case LUA_TNUMBER:
    /* get outcome to c */
    outcome = (long long *)malloc(pn * sizeof(long long));
    for (long long i = 0; i < pn; i++) {
      lua_geti(L, 2, i + 1);
      /* ...;-1=c; */
      outcome[i] = lua_tointegerx(L, -1, &good) - 1;
      luaL_argcheck(L, good && outcome[i] >= 0 && outcome[i] < lan[i], 1,
                    "invalid choice index, some value is not a in-range int");
      lua_pop(L, 1);
      /* ...; */
    }
    lua_pop(L, 1);
    *is_mixed = 0;
    return (void *)outcome;

  default:
    luaL_argerror(L, 2, "invalid outcome");
    return NULL;
  }
}

/******************************
 * Payoff calculation section *
 ******************************/

/* Internal function for shushushu. <shu> will be modified correctly by plus
 * one. Ignore all actions whose probility is zero
 *
 * Return 1 when overflowed, or 0.
 *
 *    <G> Game's infomation
 *  <shu> need to be shu, lowest number in first
 * <skip> if certain skip is zero, just skip it (plus more 1) */
static int not_a_makeinu(const struct Game_Info *G, long long *shu,
                         const double skip[]) {
  long long michiru, itsumi;
  long long shu_l;
  long long *lan;

  shu_l = G->players_amount;
  lan = G->local_actions_amount;

  /* first thing is plus one or more */
  do {
    shu[0] += 1;
    if (shu[0] == lan[0]) {
      shu[0] = 0;
      shu[1] += 1;
    }
  } while (skip[shu[0]] <= 0.0);

  /* then considering overflow */
  michiru = lan[0];
  for (long long i = 1; i < shu_l - 1; i++) {
    itsumi = shu[i] - lan[i];
    assert(itsumi <= 0);
    if (itsumi == 0) {
      /* carry */
      shu[i] = 0;
      shu[i + 1] += 1; /* @here */
    }

    /* here we detect choices-probility, if a single one is 0 then skip */
    while (skip[shu[i] + michiru] <= 0.0) {
      shu[i] += 1;
      if (shu[i] == lan[i]) {
        shu[i] = 0;
        shu[i + 1] += 1; /* @here will not happened in same time */
        itsumi = 0;
      }
    }

    /* here 'itsumi==0' means a carry happened, loop should be continue */
    if (itsumi != 0)
      /* or no more carry, just return */
      return 0;

    michiru += lan[i];
  }

  /* all the way to the hightest number, if the highest number overflowed, it is
   * overflowed overall */
  while (shu[shu_l - 1] < lan[shu_l - 1] &&
         skip[shu[shu_l - 1] + michiru] <= 0.0)
    shu[shu_l - 1] += 1;
  if (shu[shu_l - 1] == lan[shu_l - 1])
    return 1;
  else
    return 0;
}

/* Internal (or may used by ex C) function for calculation of certain payoff.
 *
 * Always put ret to <ret>.
 *
 *      <G> Game's infomation
 * <choice> an play outcome
 *    <ret> hold the result, need to be pre-alloc & reset */
void certain_payoff(const struct Game_Info *G, const long long choice[],
                    double *ret) {
  long long lancer;
  long long choice_l;
  long long *ary_hex;

  choice_l = G->players_amount;
  ary_hex = G->ary_hex;

  /* calc this outcome's index */
  lancer = 0;
  for (long long i = 0; i < choice_l; i++)
    lancer += choice[i] * ary_hex[i];

  /* copy payoff */
  memcpy(ret, G->pmtx + (lancer * choice_l), choice_l * sizeof(double));
}

/* Internal (or may used by ex C) function for calculation of mixed payoff.
 *
 * Always put ret to <ret>.
 *
 *     <G> Game's infomation
 * <mixed> mixed choices
 *   <ret> hold the result, need to be pre-alloc & reset */
void mixed_payoff(const struct Game_Info *G, const double mixed[],
                  double *ret) {
  long long pn;
  double *payoff;
  long long *eriri;
  long long megumi;
  double utaha;
  long long *lan;

  pn = G->players_amount;
  eriri = (long long *)calloc(pn, sizeof(long long));
  payoff = (double *)malloc(pn * sizeof(double));
  lan = G->local_actions_amount;
  megumi = 0;
  utaha = 0.0;

  eriri[0] = -1;
  for (;;) {
    /* call that "othoer function" to plus one or more, it will also ignore
     * actions whose probility is zero */
    if (not_a_makeinu(G, eriri, mixed))
      /* here we actully finshed all calc */
      return;

    /* a outcome has been found, what is its overall probility? */
    megumi = 0;
    utaha = 1.0;
    for (long long i = 0; i < pn; i++) {
      /* this probility is all choices-probility's product */
      utaha *= mixed[eriri[i] + megumi];
      megumi += lan[i];
    }

    /* calc this outcome's payoff */
    certain_payoff(G, eriri, payoff);
    /* add this payoff to player's mixed payoff with probility weight */
    for (long long i = 0; i < pn; i++)
      ret[i] += payoff[i] * utaha;
  }

  free(eriri);
  free(payoff);
}

/*************************************
 * Best response calculation section *
 *************************************/

/* This function find some best response for target player, in a certain choice
 * situation. This function uses a stupid method.
 *
 * Return the best response index array (need to be free after use). And put
 * the array's length in <*l>
 *
 *           <G> Game Info
 *      <choice> All players' choice, leave the target's choice meaningless. But
 *               function will still try to do not change those value
 *      <target> Target player's index
 *           <l> hold the ret array's length
 * <best_payoff> hold the ret generated payoff */
static long long *best_response_certain_fool_new(const struct Game_Info *G,
                                                 long long choice[],
                                                 const long long target,
                                                 long long *l,
                                                 double *best_payoff) {
  double *payoff;
  long long target_action_amount;
  long long *brs;
  double br_payoff;
  long long brs_l;
  long long retain;

  /* save spot */
  target_action_amount = G->local_actions_amount[target];
  retain = choice[target];

  /* In view of the best countermeasures, the best countermeasures of the
   * so-called hybrid strategy, the returns of each execution element itself
   * are completely consistent with the returns of the hybrid strategy. So look
   * for all single best countermeasures. This set can be arbitrarily combined
   * and is the best countermeasure. */
  brs_l = 0;
  br_payoff = -DBL_MAX;
  payoff = (double *)malloc(sizeof(double) * G->players_amount);
  brs = (long long *)malloc(target_action_amount * sizeof(long long));
  for (long long i = 0; i < target_action_amount; i++) {
    /* set target's choice */
    choice[target] = i;
    /* reset and calc payoff */
    memset(payoff, 0, G->players_amount * sizeof(double));
    certain_payoff(G, choice, payoff);
    /* find who is the best, if there is same best, add to collection */
    if (f_eq(payoff[target], br_payoff, PAYOFF_EPSILON, 0.0)) {
      brs_l += 1;
      brs[brs_l - 1] = i;
    } else if (payoff[target] > br_payoff) {
      /* new best is the best after all, clear the collection */
      brs_l = 1;
      brs[0] = i;
      br_payoff = payoff[target];
    }
  }
  free(payoff);

  /* recover spot */
  choice[target] = retain;

  *l = brs_l;
  *best_payoff = br_payoff;
  return brs;
}

/* This function find some best response for target player, in a mixed choice
 * situation. This function uses a stupid method.
 *
 * Return the best response index (local actions index) array (need to be
 * free after use). And putthe array's length in <l>,
 * the best reponse's payoff in <best_payoff>.
 *
 *           <G> Game Info
 *       <mixed> All players' mixed, leave the target's choice meaningless. But
 *               function will still try to do not change those value
 *      <target> Target player's index
 *           <l> hold the ret array's length
 * <best_payoff> hold the ret generated payoff */
static long long *best_response_mixed_fool_new(const struct Game_Info *G,
                                               double mixed[],
                                               const long long target,
                                               long long *l,
                                               double *best_payoff) {
  double *payoff;
  long long target_action_amount;
  long long *brs;
  double br_payoff;
  long long brs_l;
  double *target_mixed;
  long long *hell;
  double *retain;
  size_t target_mixed_size, total_payoff_size;

  /* 计算目标参与者的混合策略地址 */
  hell = G->local_actions_amount;
  target_mixed = mixed;
  for (long long i = 0; i < target; i++)
    target_mixed += hell[i];

  /* save spot */
  target_action_amount = G->local_actions_amount[target];
  target_mixed_size = (size_t)target_action_amount * sizeof(double);
  total_payoff_size = (size_t)G->players_amount * sizeof(double);
  retain = (double *)malloc(target_mixed_size);
  memcpy(retain, target_mixed, target_mixed_size);

  /* In view of the best countermeasures, the best countermeasures of the
   * so-called hybrid strategy, the returns of each execution element itself
   * are completely consistent with the returns of the hybrid strategy. So look
   * for all single best countermeasures. This set can be arbitrarily combined
   * and is the best countermeasure. */
  brs_l = 0;
  br_payoff = -DBL_MAX;
  payoff = (double *)malloc(sizeof(double) * G->players_amount);
  brs = (long long *)malloc(target_action_amount * sizeof(long long));
  for (long long i = 0; i < target_action_amount; i++) {
    /* trans action to a single element mixed strategy */
    memset(target_mixed, 0, target_mixed_size);
    target_mixed[i] = 1.0;
    /* reset and calc payoff */
    memset(payoff, 0, total_payoff_size);
    mixed_payoff(G, mixed, payoff);
    /* find who is the best, if there is same best, add to collection */
    if (f_eq(payoff[target], br_payoff, PAYOFF_EPSILON, 0.0)) {
      brs_l += 1;
      brs[brs_l - 1] = i;
    } else if (payoff[target] > br_payoff) {
      /* new best is the best after all, clear the collection */
      brs_l = 1;
      brs[0] = i;
      br_payoff = payoff[target];
    }
  }
  free(payoff);

  /* recover spot */
  memcpy(target_mixed, retain, target_mixed_size);
  free(retain);

  *l = brs_l;
  *best_payoff = br_payoff;
  return brs;
}

/* This function find a outcome is nash eq or not. IF every player's choice
 * is the best response, then it is a nash eq. That's nash eq's definition.
 *
 * Return true if is.
 *
 *      <G> Game info
 * <choice> outcome */
static int is_nash_certain_fool(const struct Game_Info *G,
                                long long outcome[]) {
  /*   long long *brs; */
  long long brs_l;
  /*   int smart; */
  double best_payoff;
  /*   long long *action_amouts = G->local_actions_amount; */
  double *payoff;

  payoff = (double *)calloc(G->players_amount, sizeof(double));
  certain_payoff(G, outcome, payoff);
  for (long long i = 0; i < G->players_amount; i++) {
    long long *nouse =
        best_response_certain_fool_new(G, outcome, i, &brs_l, &best_payoff);
    free(nouse);
    if (!f_eq(best_payoff, payoff[i], PAYOFF_EPSILON, 0.0)) {
      free(payoff);
      return 0;
    }
  }
  /*   smart = 0;
    for (long long i = 0; i < G->players_amount; i++) {
      brs = best_response_certain_fool_new(G, outcome, i, &brs_l, &best_payoff);
      for (long long j = 0; j < brs_l; j++) { */
  /* if player select the best choice? */
  /*       if (outcome[i] != brs[j])
          continue;
        smart = 1;
        break;
      }
      if (!smart) { */
  /* the choice is not in the best collection */
  /*       free(brs);
        return 0;
      }
      smart = 0;
    }

    free(brs); */
  free(payoff);
  return 1;
}

/* This function find a mixed outcome is nash eq or not. IF every player's
 * choice is the best response, then it is a nash eq.
 * That's nash eq's definition.
 *
 * Return true if is.
 *
 *     <G> Game info
 * <mixed> mixed outcome */
static int is_nash_mixed_fool(const struct Game_Info *G, double mixed[]) {
  /*   long long *brs; */
  long long brs_l;
  /*   long long process; */
  /*   long long smart; */
  double best_payoff;
  /*   long long *action_amouts = G->local_actions_amount; */
  double *payoff;

  payoff = (double *)calloc(G->players_amount, sizeof(double));
  mixed_payoff(G, mixed, payoff);
  for (long long i = 0; i < G->players_amount; i++) {
    long long *nouse =
        best_response_mixed_fool_new(G, mixed, i, &brs_l, &best_payoff);
    free(nouse);
    if (!f_eq(best_payoff, payoff[i], PAYOFF_EPSILON, 0.0)) {
      free(payoff);
      return 0;
    }
  }

  /*   process = 0;
    for (long long i = 0; i < G->players_amount; i++) {
      brs = best_response_mixed_fool_new(G, mixed, i, &brs_l, &best_payoff);
      smart = brs_l;
      for (long long j = 0; j < brs_l; j++) { */
  /* if there is a deviation, this choice is not the best, so not nash */
  /*       if (f_eq(mixed[process + brs[j]], 0.0, MIXED_EPSILON, 0.0))
          smart -= 1;
      } */
  /* not a single mixed choice element is the best */
  /*     if (!smart)
        return 0;
      process += action_amouts[i];
    } */
  free(payoff);
  return 1;
}

/**********************************
 * something export to Lua (meta) *
 **********************************/

/* Lua meta-function gc for C-obj.
 *
 * Lua_Cfun(target)
 *
 * <target> gc target */
static int game_info_gc(lua_State *L) {
  /* 1=target; */
  struct Game_Info *G = luaL_checkudata(L, 1, TOORU_EVOSIM_UDN_GAMEINFO);
  free(G->ary_hex);
  free(G->pmtx);
  free(G->local_actions_amount);
  return 0;
}

static const luaL_Reg game_info_meta[] = {{"__gc", game_info_gc}, {NULL, NULL}};

/*****************************************
 * something export to Lua (used as lib) *
 *****************************************/

/* Calculation of payoff, both mixed or not is include.
 *
 * Return a list of payoff, indexed by player index.
 *
 * Lua_Cfun(G, outcome)
 *
 *       <G> Game info
 * <outcome> comeout, mixed or not, indexed by player index and local action
 *           index */
static int payoff_ex(lua_State *L) {
  struct Game_Info *G;
  double *payoff;
  int ismixed;
  void *o;

  G = (struct Game_Info *)luaL_checkudata(L, 1, TOORU_EVOSIM_UDN_GAMEINFO);
  o = outcome_from_lua_whatever_mixed_or_not_new(L, G, 2, &ismixed);

  payoff = (double *)calloc(G->players_amount, sizeof(double));
  if (ismixed)
    mixed_payoff(G, (const double *)o, payoff);
  else
    certain_payoff(G, (const long long *)o, payoff);

  lu_number_array_list(L, payoff, G->players_amount);
  free(payoff);
  free(o);
  return 1;
}

/* Find all best response actions.
 *
 * Return two value. First is the list of br actions' local action index;
 * Second is the payoff in best response outcome.
 *
 * Lua_Cfun(G, choices, target)
 *
 *       <G> Game Info
 * <choices> mixed or not, indexed by player index and local action index,
 *           <target>'s choice can be leave meaningless
 *  <target> target player's index */
static int bset_response_ex(lua_State *L) {
  struct Game_Info *G;
  long long target;
  int ismixed;
  void *o;
  long long br_l;
  double br_payoff;
  long long *br;

  G = (struct Game_Info *)luaL_checkudata(L, 1, TOORU_EVOSIM_UDN_GAMEINFO);
  target = luaL_checkinteger(L, 3) - 1;
  luaL_argcheck(L, target >= 0 && target < G->players_amount, 3,
                "invalid br-target index");
  o = outcome_from_lua_whatever_mixed_or_not_new(L, G, 2, &ismixed);

  if (ismixed)
    br =
        best_response_mixed_fool_new(G, (double *)o, target, &br_l, &br_payoff);
  else
    br = best_response_certain_fool_new(G, (long long *)o, target, &br_l,
                                        &br_payoff);

  for (long long i = 0; i < br_l; i++)
    br[i] += 1;
  lu_integer_array_list(L, br, br_l);
  lua_pushliteral(L, "BR");
  lua_setfield(L, -2, "TAG");
  lua_pushinteger(L, target + 1);
  lua_setfield(L, -2, "TARGET");
  lua_pushnumber(L, br_payoff);
  lua_setfield(L, -2, "BR_PAYOFF");
  lua_createtable(L, 1, 0);
  lua_rotate(L, -2, 1);
  lua_seti(L, -2, 1);
  free(br);
  free(o);
  return 1;
}

/* Find out is this outcome is a nash eq or not.
 *
 * Return true or false.
 *
 * Lua_Cfun(G, outcome)
 *
 *       <G> Game Info
 * <outcome> comeout, mixed or not, indexed by player index and local action
 *           index */
static int is_nash_ex(lua_State *L) {
  struct Game_Info *G;
  int ismixed;
  void *o;

  G = (struct Game_Info *)luaL_checkudata(L, 1, TOORU_EVOSIM_UDN_GAMEINFO);
  o = outcome_from_lua_whatever_mixed_or_not_new(L, G, 2, &ismixed);

  if (ismixed)
    lua_pushboolean(L, is_nash_mixed_fool(G, (double *)o));
  else
    lua_pushboolean(L, is_nash_certain_fool(G, (long long *)o));
  free(o);
  return 1;
}

/* New a Game_info obj.
 *
 * Lua_Cfun(pn, lan, pmtx)
 *
 *   <pn> players amount
 *  <lan> local actions amount of each player
 * <pmtx> full size payoff mtx */
static int init_game_info_ex(lua_State *L) {
  /* 1=pn;2=lan;3=pmtx */
  long long pn;
  long long *lan;
  long long *ary_hex;
  double *pmtx;
  long long tmp;
  long long mixed_len;
  struct Game_Info *G;

  /* this arg check is partial, due to some calculation needed is so costed,
   * wait for ary_hex calculated */
  pn = luaL_checkinteger(L, 1);
  luaL_checktype(L, 2, LUA_TTABLE);
  luaL_checktype(L, 3, LUA_TTABLE);
  luaL_argcheck(L, pn > 1, 1, "invalid player amount");
  luaL_argcheck(L, luaL_len(L, 2) == pn, 2,
                "invalid local actions amount, its length should be equ to "
                "players amount");

  /* process lan */
  lan = malloc(pn * sizeof(long long));
  luaL_argcheck(L, lu_integer_list_array(L, 2, 1, pn, lan), 2,
                "invalid local actions amount");
  for (long long i = 0; i < pn; i++)
    luaL_argcheck(L, lan[i] > 0, 2, "local actions amount invalid");
  /* calc ary/hex & mixed_len count */
  ary_hex = (long long *)malloc(pn * sizeof(long long));
  ary_hex[0] = 1;
  mixed_len = lan[0];
  for (long long i = 1; i < pn; i++) {
    ary_hex[i] = ary_hex[i - 1] * lan[i - 1];
    mixed_len += lan[i];
  }
  /* ... */

  /* now we can check pmtx, due to ary_hex calculated */
  tmp = luaL_len(L, 3);
  luaL_argcheck(L, tmp == ary_hex[pn - 1] * lan[pn - 1] * pn, 3,
                "payoff mtx's length is invalid with players' info");
  /* process pmtx */
  pmtx = (double *)malloc(tmp * sizeof(double));
  luaL_argcheck(L, lu_number_list_array(L, 3, 1, tmp, pmtx), 3,
                "invalid payoff mtx, some value is not a number");
  /* ... */

  /* new a udata */
  G = lua_newuserdatauv(L, sizeof(struct Game_Info), 1);
  /* ...;-1=G */
  if (luaL_newmetatable(L, TOORU_EVOSIM_UDN_GAMEINFO))
    /* ...;-2=G;-1=G_meta; */
    luaL_setfuncs(L, game_info_meta, 0);
  lua_pop(L, 1);
  /* ...;-1=G; */
  luaL_setmetatable(L, TOORU_EVOSIM_UDN_GAMEINFO);

  G->ary_hex = ary_hex;
  G->local_actions_amount = lan;
  G->players_amount = pn;
  G->pmtx = pmtx;
  G->mixed_len = mixed_len;
  return 1;
}

static const luaL_Reg others[] = {{"payoff", payoff_ex},
                                  {"best_response", bset_response_ex},
                                  {"is_nash", is_nash_ex},
                                  {"new", init_game_info_ex},
                                  {NULL, NULL}};

TOORU_EXPORT int luaopen_libtooru_others(lua_State *L) {
  luaL_newlib(L, others);
  return 1;
}
