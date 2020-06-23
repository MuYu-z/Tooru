/* 2019.5.20
 * Project Tooru
 * libtooru.so evo game simulation function for lua mod */

#include "tooru.h"
#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

extern void certain_payoff(const struct Game_Info *G, const long long choice[],
                           double *ret);
extern void mixed_payoff(const struct Game_Info *G, const double mixed[],
                         double *ret);
extern void lu_number_array_list(lua_State *L, const double *arr,
                                 const long long l);

/* struct History is a C Object used for recording a game turn */
struct History {
  long long *choice;
  double *payoff;
  double *fit;
  long long *distri;
  double avg_fit;
};

/* struct Historys is a Lua-C Object used for regenize all turns records */
struct Historys {
  struct History *arr;
  long long sp;
  long long an;
  double si;
  double mi;
  long long _len;
  long long _cap;
  struct Game_Info *G;
};

#define INIT_HS_LEN 765
#define STPE_HS_LEN 100

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 * * * * * * * * * INTERNAL CALCULATION FUNCTION * * * * * * * * * * * * *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

/* Internal function calculating fit value for history.
 * Calculated target History Obj. must be pre-alloc memory. Fit calculation
 * need payoff, choice, and distri all be done. Calculated result will be
 * filled in pre-alloc memory.
 *
 *  <h> calculation target History Obj. with all memory alloced
 * <sp> simulation population
 * <an> actions number */
static void recalc_fit(struct History *h, long long sp, long long an) {
  h->avg_fit = 0.0;
  for (long long i = 0; i < sp; i++)
    h->fit[h->choice[i]] += h->payoff[i];
  for (long long i = 0; i < an; i++)
    h->avg_fit += h->fit[i] * h->distri[i];
  h->avg_fit = h->avg_fit / (double)sp;
  return;
}

/* Internal function calculating distribution for history.
 * Calculated target History Obj. must be pre-alloc memory. Distri calculation
 * need choice be done. Calculated result will be filled in pre-alloc memory.
 *
 *  <h> calculation target History Obj. with all memory alloced
 * <sp> simulation population */
static void recalc_stat(struct History *h, long long sp) {
  long long *stat = h->distri;
  for (int i = 0; i < sp; i++)
    stat[h->choice[i]]++;
  return;
}

/* Internal function calculating payoff for history
 *
 * Calculated target History Obj. must be pre-alloc memory. Payoff calculation
 * need choice be done. Calculated result will be filled in pre-alloc memory.
 *
 *  <G> Game information
 *  <h> calculation target History Obj. with all memory alloced
 * <sp> simulation population */
static void recalc_py(const struct Game_Info *G, struct History *h,
                      long long sp) {
  long long long_live[2];
  double Communist_Party[2];
  double *payoff = h->payoff;
  long long *choice = h->choice;
  for (long long i = 0; i < sp; i++) {
    long_live[0] = choice[i];
    for (long long j = i + 1; j < sp; j++) {
      long_live[1] = choice[j];
      certain_payoff(G, long_live, Communist_Party);
      payoff[i] += Communist_Party[0];
      payoff[j] += Communist_Party[1];
    }
  }
}
/* Internal function calculating payoff for history.
 *
 * Calculated target History Obj. must be pre-alloc memory. Payoff calculation
 * need choice be done. Calculated result will be filled in pre-alloc memory.
 *
 *  <L> needed Lua VM, this function need Lua VM to call payoff function
 *  <h> calculation target History Obj. with all memory alloced
 * <sp> simulation population
 *
 * LUA C STACK
 * BEFORE: -2=pf1; -1=pf2;
 *  AFTER: (balance)                                                          */
// static void recalc_py(lua_State *L, struct History *h, long long sp) {
//   double *payoff = h->payoff;
//   long long *choice = h->choice;
//   lua_createtable(L, 2, 0);
//   /* ...; -1=tmp_list; */
//   for (long long i = 0; i < sp; i++) {
//     lua_pushinteger(L, choice[i]);
//     /* ...; -2=tmp_list; -1=ic; */
//     lua_seti(L, -2, 1);
//     /* ...; -1={ic}; */
//     for (long long j = i + 1; j < sp; j++) {
//       lua_pushinteger(L, choice[j]);
//       /* ...; -2={ic,(jc)}; -1=jc; */
//       lua_seti(L, -2, 2);
//       /* ...; -1={ic,jc}; */
//       lua_pushvalue(L, -3);
//       /* ...; -2={ic,jc}; -1=pf1; */
//       lua_pushvalue(L, -2);
//       /* ...; -3={ic,jc}; -2=pf1; -1={ic,jc}; */
//       lua_call(L, 1, 1);
//       /* ...; -2={ic,jc}; -1=ret1; */
//       payoff[i] += lua_tonumber(L, -1);
//       lua_pop(L, 1);
//       /* ...; -1={ic,jc}; */
//       lua_pushvalue(L, -2);
//       /* ...; -2={ic,jc}; -1=pf2; */
//       lua_pushvalue(L, -2);
//       /* ...; -3={ic,jc}; -2=pf2; -1={ic,jc}; */
//       lua_call(L, 1, 1);
//       /* ...; -2={ic,jc}; -1=ret2; */
//       payoff[j] += lua_tonumber(L, -1);
//       lua_pop(L, 1);
//       /* ...; -1=tmp_list; */
//     }
//   }
//   lua_pop(L, 1);
//   /* (balance) */
// }

/* Internal function for new & calc a new log from a record of choice.
 *
 * Return new log pointer.
 *
 *     <hs> need to be add new log
 * <choice> a record of choice, this array will be directly used, do not
 *          free it manully */
static struct History *new_log_from_choice(struct Historys *hs,
                                           long long *choice) {
  struct History *nh, *oh;

  if (hs->_len == hs->_cap) {
    /* expand hs cap */
    hs->_cap += STPE_HS_LEN;
    oh = hs->arr;
    hs->arr = (struct History *)malloc(hs->_cap * sizeof(struct History));
    memcpy(hs->arr, oh, hs->_len * sizeof(struct History));
    free(oh);
  }

  nh = hs->arr + hs->_len;
  hs->_len += 1;
  nh->choice = choice;
  nh->distri = (long long *)calloc(hs->an, sizeof(long long));
  nh->payoff = (double *)calloc(hs->sp, sizeof(double));
  nh->fit = (double *)calloc(hs->an, sizeof(double));
  recalc_stat(nh, hs->sp);
  recalc_py(hs->G, nh, hs->sp);
  recalc_fit(nh, hs->sp, hs->an);

  return nh;
}

/* Internal function implement Rho calculation.
 *
 * Return the fixation probability
 *
 *   <G> Game info
 *  <mu> mutation choice
 * <res> resdental choices
 *  <sp> simulation population
 *  <si> selection intense */
static double rho(const struct Game_Info *G, const long long mu,
                  const long long res[], const long long sp, const double si) {
  double *alpha;
  double pmu, pres;
  double *mixed;
  double ret;
  long long an;
  double py00[2] = {0.0};
  double py11[2] = {0.0};
  double py01[2] = {0.0};

  an = G->local_actions_amount[1];

  /* first gen mixed strategy */
  mixed = calloc(an * 2, sizeof(double));
  for (long long i = 0; i < sp; i++)
    mixed[res[i]] += 1.0;
  for (long long i = 0; i < an; i++)
    mixed[i] /= (double)sp;
  /* then calc payoff */
  memcpy(mixed + an, mixed, (size_t)an * sizeof(double));
  mixed_payoff(G, mixed, py11);
  memset(mixed, 0, (size_t)an * sizeof(double));
  mixed[mu] = 1.0;
  mixed_payoff(G, mixed, py01);
  memset(mixed + an, 0, (size_t)an * sizeof(double));
  mixed[mu + an] = 1.0;
  mixed_payoff(G, mixed, py00);
  free(mixed);

  alpha = (double *)malloc((sp - 1) * sizeof(double));
  for (long long i = 1; i <= sp - 1; i++) {
    pmu = (i - 1) / (sp - 1) * py00[0] + (sp - i) / (sp - 1) * py01[0];
    pres = i / (sp - 1) * py01[1] + (sp - i - 1) / (sp - 1) * py11[0];
    alpha[i - 1] = exp(-si * (pmu - pres));
  }
  ret = 1.0 + alpha[0];
  for (long long i = 1; i < sp - 1; i++) {
    alpha[i] *= alpha[i - 1];
    ret += alpha[i];
  }
  free(alpha);
  return 1.0 / ret;
}

/* Internal function implement pairs model's detail.
 *
 * Return true if changed.
 *
 *      <hs> historys
 * <changed> return arg, changed player's index, minus means mutant but not
 *           replace */
static int pairs(struct Historys *hs, long long *changed) {
  long long student, model, change2;
  struct History *h;
  long long *c, *choice;

  h = hs->arr + hs->_len - 1;
  choice = h->choice;
  /* first thing is choose a student */
  student = rand() % hs->sp;
  change2 = choice[student];

  /* need mutation? and it's happenning? */
  if (hs->mi > 0.0 && (((double)rand() / (double)RAND_MAX) < hs->mi)) {
    /* make mutantion, and sure it is happenning */
    do
      change2 = rand() % hs->an;
    while (change2 == choice[student]);
    /* minus means mutant but not replace */
    *changed = -student;
  } else {
    /* no mutation, then choose a model, IF make sure is learning. this could
     * make a little speed up, but may offense the original pairs model */
    /* do */
    model = rand() % hs->sp;
    /* while (change2 == choice[model]); */
    if (((double)rand() / (double)RAND_MAX) <
        (1.0 /
         (1.0 + (exp(-hs->si * (h->payoff[model] - h->payoff[student]))))))
      /* replace happened */
      change2 = choice[model];
    *changed = student;
  }

  /* in spite of change happened or not, new log is needed */
  c = (long long *)malloc(hs->sp * sizeof(long long));
  memcpy(c, choice, hs->sp * sizeof(long long));
  c[student] = change2;
  h = new_log_from_choice(hs, c);
  return change2 == choice[student] ? 0 : 1;
}

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 * * * * * * * * * * * * * HISTORY(S) METHODS  * * * * * * * * * * * *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

/* define userdata's name */
#define TOORU_EVOSIM_UDN_HISTORYS "tooru_evosim_history"

/* Lua function go one turn the evo process. This function will calculate
 * and generate a new History log, according to the well-used evo model,
 * 'pairs'.
 *
 * Return changed index when changed (minus means mutant). And then
 * return a list of chance for every exist strategy to dominate.
 * If no changed just return nil.
 *
 * Lua_Cfun() */
static int historys_pairs_step(lua_State *L) {
  /* 1=self; */
  long long changed;
  struct Historys *hs;
  struct History *h;
  double *invatation;
  long long *choice;
  const struct Game_Info *G;

  hs = luaL_checkudata(L, 1, TOORU_EVOSIM_UDN_HISTORYS);
  h = hs->arr + hs->_len;
  G = hs->G;

  if (pairs(hs, &changed))
    lua_pushinteger(L, changed);
  else
    /* nothing */
    return 0;
  /* 1=self;2=changed */

  /* gen chance */
  choice = h->choice;
  invatation = (double *)calloc(hs->an, sizeof(double));
  for (long long i = 0; i < hs->sp; i++) {
    if (invatation[choice[i]] > 0)
      continue;
    invatation[choice[i]] = rho(G, choice[i], choice, hs->sp, hs->si);
  }
  /* push chance to Lua stack */
  lu_number_array_list(L, invatation, hs->an);
  /* ...;-1=chance */
  free(invatation);
  return 2;
}

/* Lua function go over the evolution process. Return stoped turn number.
 *
 * Lua_Cfun(stop, limit)
 *
 *  <stop> how much times there is no change to stop whole evo process
 * <limit> max turn to last */
static int historys_pairs_dash(lua_State *L) {
  /* 1=self;2=stop;3=limit; */
  struct Historys *hs;
  long long stop, limit, nochange_n, changed;

  hs = luaL_checkudata(L, 1, TOORU_EVOSIM_UDN_HISTORYS);
  stop = luaL_checkinteger(L, 2);
  limit = luaL_checkinteger(L, 3);
  luaL_argcheck(L, limit > 0, 3, "invalid limit");
  luaL_argcheck(L, stop > 0 && stop < limit, 2, "invalid stop");

  nochange_n = 0;
  for (long long round = 1; round <= limit; round++) {
    if (pairs(hs, &changed))
      nochange_n = 0;
    else
      nochange_n += 1;
    if (nochange_n >= stop) {
      lua_pushinteger(L, round);
      return 1;
    }
  }
  lua_pushinteger(L, limit);
  return 1;
}

/* Lua function find requested content in C-obj Historys.
 *
 * Lua_Cfun(top_index, field, index)
 *
 * <top_index> requested index in Historys
 *     <field> requested History field
 *     <index> requested index in field */
static int historys_req(lua_State *L) {
  /* 1=self; 2=top_index; 3=field; 4=index; */
  struct Historys *hs =
      (struct Historys *)luaL_checkudata(L, 1, TOORU_EVOSIM_UDN_HISTORYS);
  const char *k = luaL_checkstring(L, 3);
  const long long index = lua_tointeger(L, 4);
  if (index <= 0) {
    const char *f = lua_tostring(L, 4);
    luaL_argcheck(L, f && !strcmp(f, "avg") && k[0] == 'f', 4,
                  "invalid inner index");
  }
  /* Attention Please! Request for top index '0' is interpret to the initial
   * history record. No need for minus 1 to adjust for Lua list index. */
  const long long top_index = luaL_checkinteger(L, 2);
  luaL_argcheck(L, top_index < hs->_len && top_index >= 0, 2,
                "out of historys range");
  struct History *h = hs->arr + top_index;

  switch (k[0]) {
  case 'c':
    luaL_argcheck(L, index <= hs->sp && index > 0, 4, "out of choice range");
    lua_pushinteger(L, h->choice[index - 1] + 1);
    break;
  case 'p':
    luaL_argcheck(L, index <= hs->sp && index > 0, 4, "out of payoff range");
    lua_pushnumber(L, h->payoff[index - 1]);
    break;
  case 'd':
    luaL_argcheck(L, index <= hs->an && index > 0, 4, "out of distri range");
    lua_pushinteger(L, h->distri[index - 1]);
    break;
  case 'f':
    if (index <= 0) {
      lua_pushnumber(L, h->avg_fit);
    } else {
      luaL_argcheck(L, index <= hs->an && index > 0, 4, "out of fit range");
      lua_pushnumber(L, h->fit[index - 1]);
    }
    break;
  default:
    luaL_argerror(L, 3, "invalid field");
    break;
  }
  return 1;
}

/* Lua meta-function gc for C-obj.
 *
 * Lua_Cfun(target)
 *
 * <target> gc target */
static int historys_gc(lua_State *L) {
  /* 1=target; */
  struct Historys *hs = luaL_checkudata(L, 1, TOORU_EVOSIM_UDN_HISTORYS);
  struct History *p = hs->arr;
  for (long long i = 0; i < hs->_len; i++) {
    p = hs->arr + i;
    free(p->choice);
    free(p->distri);
    free(p->payoff);
    free(p->fit);
  }
  free(hs->arr);
  return 0;
}

/* Lua meta-function len for C-obj.
 *
 * Lua_Cfun(target)
 *
 * <target> len target */
static int historys_len(lua_State *L) {
  /* 1=target */
  struct Historys *hs = luaL_checkudata(L, 1, TOORU_EVOSIM_UDN_HISTORYS);
  /* This return value minus 1, due to historys contains an initial record
   * should be index by '0'. This 0-indexed-item is not be counted in length
   * in Lua rule. */
  lua_pushinteger(L, hs->_len - 1);
  return 1;
}

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 * * * * * * * * * * * * * * * * MOD FUNCTIONS * * * * * * * * * * * * *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
static const luaL_Reg historys_mthd[] = {
    {"req", historys_req},
    {"dash_with_pairs", historys_pairs_dash},
    {"step_with_pairs", historys_pairs_step},
    {NULL, NULL}};

static const luaL_Reg historys_meta[] = {
    {"__gc", historys_gc}, {"__len", historys_len}, {NULL, NULL}};

/* New a Historys C-obj.
 *
 * Lua_Cfun(init_choice, pf1, pf2, an, sp, si, mi)
 *
 * <init_choice> a Lua_list stand for eveybody's choice
 *          <an> #game.actions
 *          <sp> game.attr.simulation_population
 *          <si> game.attr.selection_intensity
 *          <mi> game.attr.mutation_intensity
 *           <G> game info */
static int init_historys(lua_State *L) {
  /* 1=init_choice;2=an;3=sp;4=si;5=mi;6=G */
  luaL_checktype(L, 1, LUA_TTABLE);
  struct Game_Info *G =
      (struct Game_Info *)luaL_checkudata(L, 6, TOORU_EVOSIM_UDN_GAMEINFO);
  lua_pop(L, 1);
  /* 1=init_choice;2=an;3=sp;4=si;5=mi; */
  /* set method and meta table and some little attrs for new Historys */
  struct Historys *hs =
      (struct Historys *)lua_newuserdatauv(L, sizeof(struct Historys), 1);
  /* ...; 6=hs */
  if (luaL_newmetatable(L, TOORU_EVOSIM_UDN_HISTORYS)) {
    /* ...; 6=hs; 7=historys_meta; */
    luaL_setfuncs(L, historys_meta, 0);
    lua_pushliteral(L, "__index");
    /* ...; 6=hs; 7=historys_meta; 8="__index"; */
    luaL_newlib(L, historys_mthd);
    /* ...; 6=hs; 7=historys_meta; 8="__index"; 9=historys_mthd; */
    lua_rawset(L, -3);
  }
  /* ...;6=hs;7=historys_meta; */
  lua_pop(L, 1);
  /* 1=init_choice;2=an;3=sp;4=si;5=mi;6=hs; */
  luaL_setmetatable(L, TOORU_EVOSIM_UDN_HISTORYS);
  hs->sp = luaL_checkinteger(L, 3);
  luaL_argcheck(L, hs->sp > 1, 6, "invalid simulation population");
  hs->an = luaL_checkinteger(L, 2);
  luaL_argcheck(L, hs->an > 1, 5, "invalid action number");
  hs->si = luaL_checknumber(L, 4);
  luaL_argcheck(L, hs->si > 0.0, 7, "invalid selection intense");
  hs->mi = luaL_checknumber(L, 5);
  luaL_argcheck(L, hs->mi >= 0.0, 8, "invalid mutation intense");
  lua_rotate(L, 1, 1);
  /* 1=hs;2=init_choice;3=an;4=sp;5=si;6=mi */
  lua_pop(L, 4);
  /* 1=hs;2=init_choice; */

  hs->G = G;

  /* initialize 0-th turn */
  hs->arr = (struct History *)malloc(INIT_HS_LEN * sizeof(struct History));
  hs->_len = 0;
  hs->_cap = INIT_HS_LEN;
  long long *choice = (long long *)malloc(hs->sp * sizeof(long long));
  /* gen from choice */
  luaL_argcheck(L, luaL_len(L, 2) == hs->sp, 1, "choice length is not equ with"
                                                " simulation population");
  int good;
  for (long long i = 0; i < hs->sp; i++) {
    lua_geti(L, 2, i + 1);
    /* ...;-1=c; */
    choice[i] = lua_tointegerx(L, -1, &good) - 1;
    luaL_argcheck(L, good && choice[i] >= 0 && choice[i] < hs->an, 1,
                  "invalid choice index, not a int");
    lua_pop(L, 1);
    /* ...; */
  }
  new_log_from_choice(hs, choice);

  lua_pop(L, 1);
  /* 1=hs */
  srand((unsigned int)time(NULL));

  /* gen chance */
  choice = hs->arr->choice;
  double *invatation = (double *)calloc(hs->an, sizeof(double));
  for (long long i = 0; i < hs->sp; i++) {
    if (invatation[choice[i]] > 0)
      continue;
    invatation[choice[i]] = rho(G, choice[i], choice, hs->sp, hs->si);
  }
  /* push chance to Lua stack */
  lu_number_array_list(L, invatation, hs->an);
  /* 1=hs;2=chance */
  free(invatation);
  return 2;
}

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 * * * * * * * * * * * * * * * EXPORT  * * * * * * * * * * * * * * * *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

static const luaL_Reg evosimlib[] = {{"new", init_historys}, {NULL, NULL}};

TOORU_EXPORT int luaopen_libtooru_evosim(lua_State *L) {
  luaL_newlib(L, evosimlib);
  return 1;
}
