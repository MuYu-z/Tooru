-- 2019.4.17
-- Project Tooru
-- Repeat game

local csg = require "tooru/gmod/csg"
local ge = require "tooru/game-element"
local xtable = require "std.table"

local _mod = {
  WHO = "Repeat Game",
  SERIALIZORS = {},
  TYPE = "rpg"
}

local function hs_req(self, top_i, char, i)
  if char == 'choice' then
    return self[top_i][i]
  else
    return self[top_i][char][i]
  end
end

----------------------------------------------------------------- INIT function
local function init(game, ini)
  -- 策略初始化
  for _, s in ipairs(ini.strategies) do
    -- upvalue may need more necessary function such as 'math'
    s.upvalue_req.math = math
    s.upvalue_req.print = print
    s.upvalue_req.enviroment = game._enviroment
    local good, msg = load(s.sgy_fun_src, "calc function for strategy "..s.sgy_label, "t", s.upvalue_req)
    if not good then
      warn('game define error: invalid strtegies "', s.sgy_label, '": ', msg)
      return nil
    end
    table.insert(game.strategies, ge.Strategy(s.sgy_label, s.upvalue_req, good))
    game.strategies_by_label[s.sgy_label] = #game.strategies
  end

  -- NO NEED FOR THIS
  -- sometimes rep game player not follow certain strategy
  -- if #ini.strategies == 0 and #ini.player_strategies == 0 then return game end
  -- if #ini.player_strategies ~= #game.players then
  --   warn 'game define error: player amount not equ with their strategies amount'
  --   return nil
  -- end
  -- game.historys[0] = {}
  -- for i, p in ipairs(game.players) do
  --   p.strategy = game.strategies_by_label[ini.player_strategies[i]]
  --   if not p.strategy then
  --     warn('no strategy "', tostring(ini.player_strategies[i]), '" for player #"', tostring(i), '"')
  --     return nil
  --   end
  --   game.historys[0][i] = game.strategies[p.strategy].reg.INIT
  -- end

  game.historys.req = hs_req

  return game
end

------------------------------------------------ *** RPG Game instance (2/2) ***
local _ex = {
  evaluate_history = nil;
  payoff_with_discount = nil;
  copy_strategy_choice_label2idx = nil,
  copy_strategy_choice_idx2label = nil
}
------------------------------------------------ *** RPG Game instance (2/2) ***

function _ex:copy_strategy_choice_label2idx(labels)
  local csi = {}
  for pi, label in ipairs(labels) do
    csi[pi] = self.strategies_by_label[label]
    if not csi[pi] then
      warn("strategy choices transform error: invalid choice for player idx: ", tostring(pi), " & choice label: ", label)
      return nil
    end
  end
  return csi
end

function _ex:copy_strategy_choice_idx2label(idxs)
  local labels = {}
  for pi, si in ipairs(idxs) do
    if self.strategies[si] then
      labels[pi] = self.strategies[si].label
    else
      warn("strategy choices transform error: invalid choice for player idx: ", tostring(pi), " & choice lidx: ", tostring(si))
      return nil
    end
  end
  return labels
end

function _ex:evaluate_history(choices, stop)
  local historys = {{}}
  local strategies = self.strategies

  if #strategies < 1 then
    warn 'this game is not for strategy research'
    return false
  end

  for pi, si in ipairs(choices) do
    -- what does a plyaer choose to perform in first turn must be apart of
    -- the strategy
    historys[1][pi] = strategies[si].reg.INIT
  end

  for i = 2, stop do
    local outcome = {}
    for pi, si in ipairs(choices) do
      local ok, act = pcall(strategies[si].func, historys, pi)
      if not ok then
        warn('error when computing strategy ', strategies[si].label, ': ', act)
        return false
      end
      outcome[pi] = act
    end
    if type(outcome[1]) == 'string' then
      outcome = self:copy_choice_label2lidx(outcome)
      if not outcome then return nil end
    end
    historys[i] = outcome
  end

  for target, tplayer in ipairs(self.players) do
    for i = 1, #historys do
      local ok
      ok, historys[i].payoff[target] = pcall(tplayer.payoff, self.historys[i])
      if not ok then
        warn('error when computing player ', tplayer.label, "'s payoff: ", historys[i].payoff[target])
        return nil
      end
  end end

  historys.req = hs_req
  self.historys = historys
  return true
end

-- function _ex:payoff_for_player(target)
--   local tpayoff = {}
--   local tplayer = self.players[target]

--   for i = 1, #self.historys do
--     local ok
--     ok, tpayoff[i] = pcall(tplayer.payoff, self.historys[i])
--     if not ok then
--       warn('error when computing player ', tplayer.label, "'s payoff: ", tplayer[i])
--       return nil
--     end
--   end

--   return tpayoff
-- end

function _ex:payoff_with_discount(discount_factor)
  local dp = {}
  local df = discount_factor or self.attr.discount_factor
  for i, h in ipairs(self.historys) do
    local dpi = {}
    for j, p in ipairs(h.payoff) do
      dpi[j] = (df ^ (i - 1)) * p
    end
    dp[i] = dpi
  end
  return dp
end

------------------------------------------------ MOD function - repeat-game obj.
function _mod.new(ini)
  --------------------------------------------- *** RPG Game instance (1/2) ***
  local good = csg.new(ini)
  if not good then return nil end
  good.strategies = {}
  good.strategies_by_label = {}
  good.historys = {}
  good.player_strategies = {}
  good.attr.stop = tonumber(ini.stop) or 0
  good.attr.discount_factor = tonumber(ini.discount_factor) or 1
  --------------------------------------------- *** RPG Game instance (1/2) ***
  xtable.merge(good, _ex)
  return init(good, ini)
end

return _mod
