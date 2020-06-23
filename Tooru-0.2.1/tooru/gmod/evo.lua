-- 2019.4.22
-- Project Tooru
-- Evo game

-- This source code contains some not-using code. Such code is 'evosim' code,
-- for now all this functionality was implement in C mod, 'libtooru.evosim'.
-- What's more, such code cannot be easy to reuse, due to some un-study bug.

local xtable = require "std.table"
-- local tablex = require 'pl.tablex'
local rpg = require "tooru/gmod/rpg"
local u = require "tooru/u"

local les = require "libtooru.evosim"
local los = require "libtooru.others"

local _mod = {
  WHO = "Evo Game",
  SERIALIZORS = {"nfg_convertor"},
  TYPE = "evo"
}

-------------------------------------------------------------- Internal function
local function plt_format_banner(ACTIONS, PLAYERS_AMOUNT, is_ex)
  local GLOBAL_ACTIONS_AMOUNT = #ACTIONS
  local content = {}
  local map_term2i, map_i2term = {}, {}
  -- write some helpful info
  table.insert(content, "@players_amount = " .. PLAYERS_AMOUNT .. "\n")
  table.insert(content, "@global_actions_amount = " .. GLOBAL_ACTIONS_AMOUNT .. "\n")
  -- write data content
  table.insert(content, "#" .. 0 .. ":tick\t")
  map_term2i["tick"] = 0
  local n = 1
  for i = 1, PLAYERS_AMOUNT do
    table.insert(content, ("#%d:choice-P%d\t"):format(n, i))
    map_term2i["choice-P" .. i] = n
    n = n + 1
    table.insert(content, ("#%d:payoff-P%d\t"):format(n, i))
    map_term2i["payoff-P" .. i] = n
    n = n + 1
  end
  table.insert(content, "#" .. n .. ":fit-avg\t")
  map_term2i["fit-avg"] = n
  n = n + 1
  for i = 1, GLOBAL_ACTIONS_AMOUNT do
    table.insert(content, ("#%d:distribution-%s\t"):format(n, ACTIONS[i].label))
    map_term2i["distribution-" .. ACTIONS[i].label] = n
    n = n + 1
    table.insert(content, ("#%d:fit-%s\t"):format(n, ACTIONS[i].label))
    map_term2i["fit-" .. ACTIONS[i].label] = n
    n = n + 1
  end
  if is_ex then
    for i = 1, GLOBAL_ACTIONS_AMOUNT do
      table.insert(content, ("#%d:rho-%s\t"):format(n, ACTIONS[i].label))
      map_term2i["rho-" .. ACTIONS[i].label] = n
      n = n + 1
    end
  end

  for t, i in pairs(map_term2i) do
    map_i2term[i] = t
  end
  return table.concat(content), map_term2i, map_i2term
end

local function plt_reunion_adish(hs, PLAYERS_AMOUNT, GLOBAL_ACTIONS_AMOUNT, from, to)
  local content = {}
  to = to or from or #hs
  -- 0 is the index of initial record
  from = from or 0

  -- write data
  for i = from, to do
    local item = {}
    for j = 1, PLAYERS_AMOUNT do
      table.insert(item, hs:req(i, "c", j))
      table.insert(item, hs:req(i, "p", j))
    end
    table.insert(item, hs:req(i, "f", "avg"))
    for j = 1, GLOBAL_ACTIONS_AMOUNT do
      table.insert(item, hs:req(i, "d", j))
      table.insert(item, hs:req(i, "f", j))
    end
    table.insert(content, item)
  end
  return content
end

-- The two functions above is used to union the historys used to render output.
-- Because this historys data are so unique, this union code in here but not
-- in render code. Render code recive this kind of reunioned data to format.

-- local function recalc_fit(historys, game)
--   local fit = tablex.new(#game.actions, 0)
--   for i, c in ipairs(historys.choice) do
--     fit[c] = fit[c] + historys.payoff[i]
--   end
--   fit.avg = 0
--   for i, f in ipairs(fit) do
--     fit.avg = fit.avg + (f * historys.distri[i])
--   end
--   fit.avg = fit.avg / game.attr.simulation_population
--   return fit
-- end

-- local function recalc_status(historys, game)
--   local stat = tablex.new(#game.actions, 0)
--   for _, c in ipairs(historys.choice) do
--     stat[c] = stat[c] + 1
--   end
--   return stat
-- end

-- local function recalc_payoff(historys, game)
--   local payoff = tablex.new(game.attr.simulation_population, 0)
--   for i, ic in ipairs(historys.choice) do
--     for j = i + 1, #historys.choice do
--       local jc = historys.choice[j]
--       payoff[i] = payoff[i] + game.players[1].payoff({ic, jc})
--       payoff[j] = payoff[j] + game.players[2].payoff({ic, jc})
--     end
--   end
--   return payoff
-- end

-- pairs model
-- local function step(game)
--   local changed = false
--   local now = u.clone(game.historys[#game.historys])
--   local student, model
--   repeat
--     student, model =
--       math.random(game.attr.simulation_population),
--       math.random(game.attr.simulation_population)
--   until student ~= model
--   local student_pay, model_pay = now.payoff[student], now.payoff[model]
--   local p =
--     1 /
--     (1 + (math.exp(-game.attr.selection_intensity * (model_pay - student_pay))))
--   if p > math.random() then
--     now.choice[student] = now.choice[model]
--     now.payoff = recalc_payoff(now.choice, game._payoff_mtx)
--     now.distri = recalc_status(now.choice)
--     now.fit = recalc_fit(now.choice)
--     changed = true
--   end
--   table.insert(game.historys, now)
--   return changed
-- end

------------------------------------------------------------------- INIT function
local function init(game, ini)
  -- math.randomseed(os.time())

  -- 初始化状态
  -- if 0 == ini.simulation_population then
  --   warn "evo infinity population waring: cannot simulation evo process, only do theoretically analysis"
  --   return nil
  -- end
  local init_choice, join_the_party = {}, 0
  -- in evo game, act local index is same as global index
  for sgy, pop in pairs(ini.init_distri) do
    if not game.actions_by_label[sgy] then
      warn('invalid init distribution define: no such a action "', sgy, '"')
      return nil
    end
    if math.type(pop) == "float" then
      local gayfriend = pop * ini.simulation_population
      local overcook = math.floor(gayfriend)
      if overcook < pop then
        warn("evo population approximately warning: initial population distribution calculation is not accurate for stratrgy ", tostring(sgy), ", original distribution is ", tostring(pop), ", population result ", tostring(gayfriend), " is approximately equal to ", tostring(overcook))
      end
      pop = overcook
    end
    for _ = 1, pop do
      if join_the_party == ini.simulation_population then
        warn('evo overflow population waring: too much players defined in initial distribution, cutting strategy "', tostring(sgy))
        break
      end
      join_the_party = join_the_party + 1
      init_choice[join_the_party] = game.actions_by_label[sgy]
    end
  end
  if join_the_party < ini.simulation_population then
    warn("evo population approximately warning: initial population cannot be fullfilled due to approxmate or define error, there is only ", tostring(join_the_party), " players defined where the total population is ", tostring(ini.simulation_population), ", the rest will be done with last assignation")
    for i = join_the_party + 1, ini.simulation_population do
      init_choice[i] = init_choice[i - 1]
    end
  end

  game.init_choice = init_choice
  game.C_GAME_INFO = los.new(2, {#game.actions, #game.actions}, game.PAYOFF_MTX)
  game.historys, game.init_chance =
    les.new(
    init_choice,
    #game.actions,
    ini.simulation_population,
    ini.selection_intensity,
    ini.mutations_intensity,
    game.C_GAME_INFO
  )
  -- game.historys = {}
  -- game.historys[1] = {}
  -- game.historys[1].choice = init_choice
  -- game.historys[1].distri = recalc_status(game.historys[1], game)
  -- game.historys[1].payoff = recalc_payoff(game.historys[1], game)
  -- game.historys[1].fit = recalc_fit(game.historys[1], game)

  return game
end -- end of init

---------------------------------------------------- Export function for newgame
------------------------------------------------ *** EVO Game instance (2/2) ***
local _ex = {
  quick_evo = nil,
  evo = nil,
  evo_step = nil,
  reset = nil
}
------------------------------------------------ *** EVO Game instance (2/2) ***

-- This function make a compelete evosim process, it is soooooooooooo quick.
-- Just return when it is stop.
function _ex:quick_evo(stop, limit, rnd)
  local when_stop = self.historys:dash_with_pairs(stop, limit)

  local banana, map_term2i, map_i2term = plt_format_banner(self.actions, self.attr.simulation_population)
  local good, msg = rnd:banner(banana)
  if not good then
    warn(msg)
    return nil
  end
  good, msg = rnd:write(plt_reunion_adish(self.historys, self.attr.simulation_population, #self.actions))
  if not good then
    warn(msg)
    return nil
  end

  rnd._plot_aux = {map_term2i, map_i2term}
  return when_stop
end

-- This function is not 'that' quick, but it can make rho calculation.
function _ex:evo(stop, limit, rnd)
  local banana, map_term2i, map_i2term = plt_format_banner(self.actions, self.attr.simulation_population, true)
  local good, msg = rnd:banner(banana)
  if not good then
    warn(msg)
    return nil
  end
  rnd._plot_aux = {map_term2i, map_i2term}

  -- make initial data on
  local content = plt_reunion_adish(self.historys, self.attr.simulation_population, #self.actions, 0)
  -- here we concat rho list to original historys data list
  -- due to only 1 item of data is generated, so just process 'content[1]'
  u.append(content[1], self.init_chance)
  good, msg = rnd:write(content)
  if not good then
    warn(msg)
    return nil
  end

  local nochange = 0
  local last_chance = self.init_chance
  for i = 1, limit do
    local changed, chance = self.historys:step_with_pairs()
    if changed then
      nochange = 0
      last_chance = chance
    else
      nochange = nochange + 1
      chance = last_chance
    end
    assert(#chance == #self.actions, "gen-ed chance's length is wrong")

    -- make data t
    content = plt_reunion_adish(self.historys, self.attr.simulation_population, #self.actions, i)
    -- here we concat rho list to original historys data list
    -- due to only 1 item of data is generated, so just process 'content[1]'
    u.append(content[1], last_chance)
    good, msg = rnd:write(content)
    if not good then
      warn(msg)
      return nil
    end

    if nochange > stop then
      return i
    end
  end
  return limit
end

-- This function make you can manully control the evosim process. It just make
-- clock tick one time.
-- Return changed index when changed (minus means mutant). And then
-- return a list of chance for every exist strategy to dominate.
-- If no changed just return nil.
function _ex:evo_step()
  return self.historys:step_with_pairs()
end

function _ex:reset()
  self.historys =
    les.new(
    self.init_choice,
    #self.actions,
    self.attr.simulation_population,
    self.attr.selection_intensity,
    self.attr.mutations_intensity,
    self.C_GAME_INFO
  )
end

--------------------------------------------------- MOD function - evo-game obj.
function _mod.new(ini)
  ---------------------------------------------- *** EVO Game instance (1/2) ***
  local good = rpg.new(ini)
  if not good then return nil end
  good.attr.stop = nil -- this is a delete
  good.historys = nil
  good.init_choice = nil
  good.init_chance = nil
  good.attr.selection_intensity = ini.selection_intensity
  good.attr.mutations_intensity = tonumber(ini.mutations_intensity) or 0
  good.attr.simulation_population = ini.simulation_population
  -- 明显，当sp小于3；或者是无穷大时，模拟没有任何意义
  -- if good.attr.simulation_population > 2 then
  xtable.merge(good, _ex)
  -- end
  ---------------------------------------------- *** EVO Game instance (1/2) ***
  return init(good, ini)
end

return _mod
