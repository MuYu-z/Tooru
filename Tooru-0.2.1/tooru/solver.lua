-- 2019.4.10
-- Project Tooru
-- Game solver. Some from libgambit, some from self coding.

-- local u = require "tooru/u"
local xtable = require "std.table"
local tablex = require "pl.tablex"
local text = _G.TOORU_TEXT

-- This flag can be used to verify a game is already formated to NFG game or not
-- local gs_nfg_flag = "^NFG"

----------------------------------------------------------------- MOD
-- all of the calculators' name
local NAME = {"gnm", "ipa", "payoff", "is_nash", "best_response"}
-- where these calculators come from?
local LIBS = {
  require "libtooru.lgt",
  require "libtooru.others"
}
local _mod = {NAME = NAME, LIBS = LIBS}

-- Speciafy the solver's lib, used in initialize a solver to locate solver
-- function
local map_sl2libs = {
  gnm = LIBS[1],
  ipa = LIBS[1],
  payoff = LIBS[2],
  is_nash = LIBS[2],
  best_response = LIBS[2]
}

-- Speciafy the solver's return's type, certain type is corresponding to a
-- render's name. THIS will be used in initialize a solver to check the
-- render's compatablity.
local map_sl2rndr = {
  gnm = "outcome",
  ipa = "outcome",
  payoff = "payoff",
  is_nash = "raw",
  best_response = "strategy"
}

---------------------------------------------------- Different solve logic
-- gambit solve logic is usually need 'game.CONTENT' has a gambit format string
-- and some post-process due gambit's return is always be in CVS string.
-- local function gambit_solve(sl, game)
--   if not (type(game.CONTENT) == "string" and game.CONTENT:find(gs_nfg_flag)) then
--     error("solver error: cannot solve the game with " .. sl.NAME)
--   end
--   return u.decvs(map_sl2libs[sl.NAME][sl.NAME](game.CONTENT, sl.renders[1].attr.precision))
-- end

-- others solve logic is usually need a game_info be pre-genenerated.
local function others_solve(self, game, ...)
  if type(game.C_GAME_INFO) ~= "userdata" then
    local lan = {}
    for i, p in ipairs(game.players) do
      lan[i] = #(game.action_sets[game.types[p.type].action_set_idx])
    end
    game.C_GAME_INFO = LIBS[2].new(#game.players, lan, game.PAYOFF_MTX)
  end
  return map_sl2libs[self.NAME][self.NAME](game.C_GAME_INFO, ...)
end

-- Speciafy the solver's logic function, some solver need some pre-process
-- or post-process.
local map_sl2slog = {
  gnm = others_solve,
  ipa = others_solve,
  payoff = others_solve,
  is_nash = others_solve,
  best_response = others_solve
}

------------------------------------------------------------ Export function
------------------------------------------------ *** Solver instance (2/2) ***
local _ex = {solve = nil}
------------------------------------------------ *** Solver instance (2/2) ***

function _ex:solve(game, ...)
  local good, msg = map_sl2slog[self.NAME](self, game, ...)
  if not good and msg then
    warn('solve failed: ', msg)
    return nil
  end
  if type(good) == "table" then
    good.SOURCE = self.NAME
  end
  local ans = good
  for _, render in ipairs(self.renders) do
    if text.banner[self.NAME] then
      good, msg = render:banner(text.banner[self.NAME])
      if not good then warn('cannot write to render: ', msg) end
    end
    good, msg = render:write(ans, game)
    if not good then warn('cannot write to render: ', msg) end
  end
  return ans
end

------------------------------------------------------------- MOD function
function _mod.new(name, renders)
  if not tablex.find(NAME, name) then
    warn("no solver err: ", tostring(name))
    return nil
  end
  -- when only one renders in, we make it in list too.
  if renders.FILE then
    renders = {renders}
  end
  for _, render in ipairs(renders) do
    if map_sl2rndr[name] ~= render.NAME then
      warn("solver incompatible error: ", tostring(name), " with render ", render.NAME)
      return nil
    end
  end

  ------------------------------------------------ *** Solver instance (1/2) ***
  return xtable.merge(
    {
      renders = renders,
      NAME = name
    },
    _ex
  )
  ------------------------------------------------ *** Solver instance (1/2) ***
end

-- This is for some manully control of solve something, this solver has
--  not a render
function _mod.quick_simple_naive_new(name)
  if not tablex.find(NAME, name) then
    warn("no solver err: ", tostring(name))
    return nil
  end

  ------------------------------------------ *** Quick Solver instance ***
  return {
    NAME = name,
    solve = map_sl2slog[name]
  }
  ------------------------------------------ *** Quick Solver instance ***
end

return _mod
