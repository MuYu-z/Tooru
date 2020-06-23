-- 2019.3.29
-- Project Tooru
-- Classic simultaneous game

local xtable = require "std.table"
local ge = require "tooru/game-element"
local u = require "tooru/u"

local _mod = {
  WHO = "Classic Sim Game",
  SERIALIZORS = {"nfg_convertor"},
  TYPE = "csg"
}

-- This var used to mark the single payoff mtx in the 'ini'. All situation with
-- this mark need to be processed specially.
local single_mtx_mark = "HBC"

----------------------------------------------------------- Internal function
-- Here we make a function to calculate and store two very usable values: the
-- length of a compelete payoff mtxs and a single payoff mtx. This function
-- will only calc these two values once and cache them, so all other request
-- will no longer need re-calculating.
-- Call this function with no argments will reset the store cache.
local FruitsBasket =
  (function()
  local tooru, souma
  local function FruitsBasket(ini)
    local pmtx_len, player_num = 1, 0
    for _, t in ipairs(ini.types) do
      pmtx_len = ((#ini.action_sets[t.action_set_idx]) ^ t.player_num) * pmtx_len
      player_num = player_num + t.player_num
    end
    return pmtx_len * player_num, pmtx_len
  end

  return function(ini)
    if not ini then
      tooru, souma = nil, nil
      return
    end
    if not tooru then
      tooru, souma = FruitsBasket(ini)
    end
    return tooru, souma
  end
end)()

-- 这个函数被用来扩展单方回报矩阵，理论上可以将一个单方回报矩阵扩展为任意数量参与者的完全回报矩阵，
-- 但是目前只有双参与者的情况得到充分测试并多使用于进化博弈。
-- 补充说明：只有对此博弈才能够使用单方矩阵合理的表示，也只有如此对于单方矩阵的扩展是有意义的。换
-- 一个说法，单方矩阵是在博弈对称的情况下一种简化的回报矩阵书写方法。
local function transforms(smtx, expend_scale)
  if expend_scale == 2 then
    -- Here is the very usable source code.
    local asuna, yui = smtx, {}
    local kirito = math.sqrt(#asuna)
    if select(-1, math.modf(kirito)) ~= 0.0 then
      warn "global payoff error: invalid #1 payoff define, it is not a full payoff mtx, but cannot be expended"
      return nil
    end
    for i = 1, kirito do
      for j = 1, kirito do
        yui[((j - 1) * kirito) + i] = asuna[((i - 1) * kirito) + j]
      end
    end
    local SAO = {}
    for suguha = 1, #yui do
      table.insert(SAO, asuna[suguha])
      table.insert(SAO, yui[suguha])
    end
    return SAO
  else
    -- un-tested
    -- This kind of source code is so crazy. Just as itself say: 'SET ME FLY!'
    local new_mtx = {}
    local act_num, p_num = (#smtx) ^ (1 / expend_scale), expend_scale
    if select(-1, math.modf(act_num) ~= 0) then
      warn "global payoff error: invalid #1 payoff define, it is not a full payoff mtx, but cannot be expended"
      return nil
    end
    for i, sda in ipairs(smtx) do
      table.insert(new_mtx, sda)
      for j = 2, p_num do
        local set_myself_fly, asd = {}, 1
        repeat
          local sad = (i % (act_num ^ asd)) + 1
          table.insert(set_myself_fly, sad)
          i = math.floor((i - sad) / act_num)
        until i == 0
        for ads = #set_myself_fly + 1, p_num do
          set_myself_fly[ads] = 1
        end
        set_myself_fly[1], set_myself_fly[j] = set_myself_fly[j], set_myself_fly[1]
        local dsa = set_myself_fly[1]
        for das = 2, #set_myself_fly do
          dsa = dsa + ((set_myself_fly[dsa] - 1) * (act_num ^ (das - 1)))
        end
        table.insert(new_mtx, smtx[dsa])
      end
    end
    return new_mtx
  end
end

-- 这个函数能够成产一些闭包，这些闭包关联了一个特定的参与者，可以根据博弈结果给出该参与者
-- 所获得的具体回报。
local function factory_of_calc_payoff_from_mtx(ini, my_pos, payoff_idx)
  local full_len, single_len = FruitsBasket(ini)
  local payoff = ini.payoffs[payoff_idx]
  if type(payoff) == "table" and (#payoff == full_len) then
    -- 这意味着这是一个全局回报矩阵
    return function(choice)
      -- local action set idx
      local lancer, saber, caster = choice[1], 1, ini.types[1].player_num
      for i = 2, #choice do
        lancer = lancer + ((#ini.action_sets[ini.types[saber].action_set_idx]) ^ saber) * (choice[i] - 1)
        caster = caster - 1
        if caster == 0 then
          saber = saber + 1
          caster = ini.types[1][2]
        end
      end
      return payoff[((lancer - 1) * #choice) + my_pos]
    end
  elseif type(payoff) == "string" then
    -- 一个效用函数
    local upvalue_req
    upvalue_req.math = math
    upvalue_req.print = print
    upvalue_req.enviroment = ini.enviroment
    local good, msg = load(payoff, "payoff calc function code", "t", upvalue_req)
      if not good then
        warn("error when loading payoff function for player #", tostring(my_pos), ": ", msg);
        return nil
      end
    -- ini.payoffs should be pre-process for pass-in-arg
    return function(choice)
      return good(choice, my_pos)
    end
  elseif type(payoff) == "table" and (#payoff == single_len) then
    -- 一个单方回报矩阵，其它情况不合法
    -- return function(choice)
    --   -- 根据单方回报矩阵的计算需要将‘自己’视为第一个参与者，“第一人称”
    --   table.insert(choice, 1, table.remove(choice, my_pos))
    --   -- local action set idx
    --   local lancer, saber, caster = choice[1], 1, ini.types[1][2] --!?
    --   for i = 2, #choice do
    --     lancer =
    --       lancer +
    --       ((#ini.action_sets[ini.types[saber][3]]) ^ saber) * (choice[i] - 1)
    --     caster = caster - 1
    --     if caster == 0 then
    --       saber = saber + 1
    --       caster = ini.types[1][2]
    --     end
    --   end
    --   return payoff[lancer]
    -- end
    -- 单方矩阵不再用于直接计算，它将被扩展为完全矩阵然后用于计算
    return single_mtx_mark
  elseif type(payoff) == "table" then
    warn("payoff define error: not valid payoff #", tostring(payoff_idx), " and payoff len is ", tostring(#payoff), ", but need be ", tostring(full_len), " or ", tostring(single_len))
    return nil
  else
    warn("payoff define error: not valid payoff #", tostring(payoff_idx), " whose type is ", type(payoff))
    return nil
  end
end

-- 这是配置博弈的主要函数。它根据给出的配置表建立一个静态博弈实例。
-- 由于各个博弈之间的差异几乎都是增量的（相同的要素，各有一些附加的额外特性），我们在这里使用
-- 类似与原型模式的方案去重用代码。也就是说其他类型博弈都是基于一个他的原型（和他最接近的一个
-- 博弈类型）去产生。
local function init(game, ini)
  local good
  FruitsBasket()

  -- 初始化全局行为空间
  --[[   local araya, seikai, rasen = 1, 1, {} -- あらや そうれん
  if ini.value_switch ~= 0 then
    araya = 2 --!?
  end
  for _, enjyou in ipairs(ini.action_sets[1]) do -- えんじょう ともえ
    table.insert(rasen, enjyou)
    seikai = seikai + 1
    if seikai > araya then
      local action = ge.Action(table.unpack(rasen))
      table.insert(game.actions, action)
      game.actions_by_label[rasen[1]\] = action
      seikai = 1
    end
  end ]]
  --[[   for i, act in ipairs(ini.action_sets[1]) do
    local l, v = tostring(act), nil
    if ini.value_switch ~= 0 then
      v = act
    end
    game.actions[i] = ge.Action(l, v)
    game.actions_by_label[l] = i
  end ]]
  -- 连接行为集与程序中的行为列表——actions
  local action_sets = {}
  for idx, actions in ipairs(ini.action_sets) do
    action_sets[idx] = {}
    for _, action in ipairs(actions) do
      local l, v = tostring(action), action
      if not game.actions_by_label[l] then
        if ini.value_switch == 0 then
          v = nil
        else
          if type(action) ~= 'number' then
            warn 'game defined value-ed action, but action cannot be used to compute'
            return nil
          end
        end
        table.insert(game.actions, ge.Action(l, v))
        game.actions_by_label[l] = #game.actions
      end
      table.insert(action_sets[idx], game.actions_by_label[l])
    end
  end
  game.action_sets = action_sets

  -- 初始化参与者类型和所有的参与者
  local pos, pl = 0
  for _, t in ipairs(ini.types) do
    local type = ge.Type(t.type_label, t.action_set_idx, t.payoff_idx)
    table.insert(game.types, type)
    game.types_by_label[t.type_label] = #game.types
    for j = 1, t.player_num do
      pos = pos + 1
      -- 这里可能返回一个 HBC Single payoff mtx 标记，这写参与者的回报计算函数将延迟到完全回
      -- 报矩阵计算完成后再行绑定
      good = factory_of_calc_payoff_from_mtx(ini, pos, t.payoff_idx)
      if not good then return nil end
      if t.player_num == 1 then
        pl = t.type_label
      else
        pl = t.type_label .. "-" .. j
      end
      table.insert(game.players, ge.Player(pl, game.types_by_label[t.type_label], good))
      game.players_by_label[pl] = pos
    end
  end

  -- 初始化回报矩阵
  local full, single = FruitsBasket(ini)
  if ini.value_switch == 0 then
    if #game.payoffs[1] == full then
      game.PAYOFF_MTX = game.payoffs[1] -- !? 初始完全回报矩阵必须置于回报定义列表第一
    elseif #game.payoffs[1] == single then
      if #game.types ~= 1 then
        warn "payoff mtx error: muti-types but try to extend a single payoff mtx"
        return nil
      end
      good = transforms(game.payoffs[1], #game.players)
      if not good then return nil end
      game.PAYOFF_MTX = good
      -- HBC Project: Single mtx payoff care
      ini.payoffs[0] = good
      for i, p in ipairs(game.players) do
        if p.payoff == single_mtx_mark then
          p.payoff = factory_of_calc_payoff_from_mtx(ini, i, 0)
        end
      end
    else
      warn "payoff mtx error: invalid global payoff defination #1"
      return nil
    end
  else
    -- UNTESTED
    -- 如果开关是打开的，那么提供完全回报矩阵没有意义，之所以要打开，
    -- 就是因为没法手动计算这个矩阵
    -- value_switch on, calculate in time
    -- JUST _______ GOOGLE IT; READ THE _______ MANUAL;
    -- local action index already used
    local JFGI, RTFM = {}, {}
    game.PAYOFF_MTX = {}
    for i, p in ipairs(game.players) do
      JFGI[i] = #game.action_sets(game.types[p.type].action_set_idx)
      RTFM[i] = 1
    end
    for i = 1, full, #JFGI do
      for j = 0, #RTFM - 1 do
        local ok
        ok, game.PAYOFF_MTX[i + j] = pcall(game.players[i + j].payoff, RTFM)
        if not ok then
          warn('error when computing payoff in player ', game.players[i + j].label, '\'s function: ', game.PAYOFF_MTX[i + j])
          return nil
        end
      end
      RTFM[1] = RTFM[1] + 1
      local j, done = 1, false
      repeat
        if RTFM[j] > JFGI[j] then
          RTFM[j] = 1
          j = j + 1
          RTFM[j] = RTFM[j] + 1
        else
          done = true
        end
      until done
    end -- end of inner for
  end -- end of if-else

  game._enviroment = ini.enviroment
  return game
end -- end of init

---------------------------------------------------- Export function for newgame
------------------------------------------------ *** CSG Game instance (2/2) ***
local _ex = {
  -- This two functions trans between label and local index for actions.
  -- For people we use label to express, while for some internal calculation
  -- program use local index. And for whole game represent, global index is also
  -- needed to union then.
  copy_choice_label2lidx = nil,
  copy_choice_lidx2label = nil
}
------------------------------------------------ *** CSG Game instance (2/2) ***

function _ex:copy_choice_label2lidx(labels)
  local cli = {}
  for pi, label in ipairs(labels) do
    local cgi = self.actions_by_label[label]
    for li, gi in ipairs(self.action_sets[self.types[self.players[pi].type].action_set_idx]) do
      if gi == cgi then
        cli[pi] = li
        break
      end
    end
    if not cli[pi] then
      warn("choices transform error: invalid choice for player idx: ", tostring(pi), " & choice label: ", label)
      return nil
    end
  end
  return cli
end

function _ex:copy_choice_lidx2label(lidxs)
  local labels = {}
  for pi, cli in ipairs(lidxs) do
    if self.action_sets[self.types[self.players[pi].type].action_set_idx][cli] then
      labels[pi] = self.actions[self.action_sets[self.types[self.players[pi].type].action_set_idx][cli]].label
    else
      warn("choices transform error: invalid choice for player idx: ", tostring(pi), " & choice lidx: ", tostring(cli))
      return nil
    end
  end
  return labels
end

-- function _ex:best_response(others_choices, fresh)
--   local path = _ex.copy_choice_label2idx(self, others_choices)
--   table.insert(path, 'br')
--   if fresh then
--     self._cache:checkin(others_choices, fresh)
--   end
--   local ret = self._cache:checkout(others_choices)
--   return ret
-- end

-- function _ex:nash_equilibrium(fresh)
--   if fresh then
--     self._cache:checkin({'ne'}, fresh)
--   end
--   return self._cache:checkout({'ne'})
-- end

-- function _ex:quantal_response_equilibrium(fresh)
--   if fresh then
--     self._cache:checkin({'qre'}, fresh)
--   end
--   return self._cache:checkout({'qre'})
-- end

-- function _ex:certain_payoff(choice, fresh)
--   local path = _ex.copy_choice_label2idx(self, choice)
--   table.insert(path, 'cp')
--   if fresh then
--     self._cache:checkin(choice, fresh)
--   end
--   local ret = self._cache:checkout(choice)
--   table.remove(choice)
--   return ret
-- end

---------------------------------------------------- MOD function - Game obj.
function _mod.new(ini)
  ---------------------------------------------- *** CSG Game instance (1/2) ***
  local new_game = {
    --_cache = ge.Cache(),
    actions = {},
    types = {},
    actions_by_label = {},
    action_sets = {},
    types_by_label = {},
    players = {},
    players_by_label = {},
    PAYOFF_MTX = {},
    RAW = ini,
    CONTENT = nil,
    payoffs = u.clone(ini.payoffs),
    attr = {
      title = ini.title or "",
      comment = ini.comment or "",
      value_switch = ini.value_switch,
      game_type = ini.game_type,
      type_name = nil
    },
    C_GAME_INFO = nil,
    _enviroment = {}
  }
  ---------------------------------------------- *** CSG Game instance (1/2) ***
  xtable.merge(new_game, _ex)
  return init(new_game, ini)
end -- end of new_game

return _mod
