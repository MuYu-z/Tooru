/* 2019.9.3
 * Project Tooru
 * u is used in usual */

#include "lua54/lauxlib.h"
#include "lua54/lua.h"
#include <float.h>
#include <math.h>
#include <stdlib.h>

void lu_number_array_list(lua_State *L, const double *arr, const long long l) {
  /* first, make a table */
  lua_createtable(L, l<=INT_MAX?(int)l:INT_MAX, 0);
  /* ...;-1=list; */
  /* then, make it great again */
  for (long long i = 0; i < l; i++) {
    lua_pushnumber(L, arr[i]);
    /* ...;-2=list;-1=arr[i] */
    lua_seti(L, -2, i + 1);
    /* ...;-1=list */
  }
}

void lu_integer_array_list(lua_State *L, const long long *arr,
                           const long long l) {
  /* first, make a table */
  lua_createtable(L, l<=INT_MAX?(int)l:INT_MAX, 0);
  /* ...;-1=list; */
  /* then, make it great again */
  for (long long i = 0; i < l; i++) {
    lua_pushinteger(L, arr[i]);
    /* ...;-2=list;-1=arr[i] */
    lua_seti(L, -2, i + 1);
    /* ...;-1=list */
  }
}

int lu_integer_list_array(lua_State *L, int idx, const long long s,
                          const long long l, long long *ret) {
  int isint;
  for (long long i = 0; i < l; i++) {
    lua_geti(L, idx, i + s);
    /* ...;-1=int; */
    ret[i] = lua_tointegerx(L, -1, &isint);
    lua_pop(L, 1);
    /* ...; */
    if (!isint)
      return 0;
  }
  return 1;
}

int lu_number_list_array(lua_State *L, int idx, const long long s,
                         const long long l, double *ret) {
  int isnum;
  for (long long i = 0; i < l; i++) {
    lua_geti(L, idx, i + s);
    /* ...;-1=num; */
    ret[i] = lua_tonumberx(L, -1, &isnum);
    lua_pop(L, 1);
    /* ...; */
    if (!isnum)
      return 0;
  }
  return 1;
}

/* float is magic!
 * https://randomascii.wordpress.com/2012/02/25/comparing-floating-point-numbers-2012-edition/
 * max_diff is 绝对, while max_rel_diff is 相对. abs-error can be set accroding
 * to context. However when f1f2 is large, abs-error lost its meaning. rel-error
 * is recommand with EPSILON predefined by float.h or its small muti, Leave it 0
 * will casue the function use standard EPSILON value. */
int f_eq(double f1, double f2, double max_diff, double max_rel_diff) {
  /* Check if the numbers are really close -- needed
   * when comparing numbers near zero. */
  double diff = fabs(f1 - f2);
  if (diff <= max_diff)
    return 1;

  f1 = fabs(f1);
  f2 = fabs(f2);
  double largest = (f2 > f1) ? f2 : f1;

  if (!max_rel_diff)
    max_rel_diff = DBL_EPSILON;
  if (diff <= largest * max_rel_diff)
    return 1;
  return 0;
}