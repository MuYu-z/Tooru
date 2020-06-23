-- 2019.4.8
-- Project Tooru
-- Toml, gambit file processor

local u = require "tooru/u"

-- This is some pass-in args for loaded source code
local src_sgy_prefix = "local HISTORY,SELF = ...;"
local src_pf_prefix = "local CHOICE,SELF = ...;"
-- This is Gambie NFG game used txt
local nfg_prologue = 'NFG 1 R "%s - %s"'
local nfg_begin = "{ "
local nfg_end = "}"

--------------------------------------------------------------------------- MOD
local _mod = {
  loaders = {
    toml =nil,
    yaml = nil,
    luaraw = nil
  },
  serializors = {}
}

do -- _mod init

local ok
ok, _mod.loaders.toml = pcall(require, "toml")
if not ok then
  warn '"toml" mod not found, toml support disable'
  _mod.loaders.toml = function() error('toml support disabled') end
else _mod.loaders.toml = _mod.loaders.toml.load end
ok, _mod.loaders.yaml = pcall(require, "lyaml")
if not ok then
  warn '"yaml" mod not found, yaml support disable'
  _mod.loaders.yaml = function() error('yaml support disabled') end
else _mod.loaders.yaml = _mod.loaders.yaml.load end
_mod.loaders.luaraw = function(content)
  local ret
  if type(content) ~= 'string' then error('invalid content to load') end
  local good, msg = load('return '..content, 'game definition', 't', {})
  if not good then error('invalid game define in luaraw: '..msg) end
  ok, ret = pcall(good)
  if not ok then error('invalid game define in luaraw: '..ret) end
  return ret
end

end -- _mod init


----------------------------------------------------------------- Class diff fun
-- 由于各个博弈类型之间有着树形的相互包含关系，故从根开始（pre_process），这些预处理函数最后会检查
-- 该配置是否满足自己的子类型。如果满足则进一步细化处理。
local function read_evo(game)
  if #game.init_distri > 0 then
    local init_distri = u.split(game.init_distri)
    game.init_distri = {}
    for _, s in ipairs(init_distri) do
      local k, v = u.keypairs(s)
      -- not fully check, range check need to be done
      assert(type(k) == 'string' and type(v) == "number", "game input error: invalid evo init_distri")
      game.init_distri[k] = v
    end
  end

  assert(tonumber(game.selection_intensity) and tonumber(game.selection_intensity) > 0, 'invalid selection intensity')
  assert(tonumber(game.simulation_population) and tonumber(game.simulation_population) > 1, 'invalid simulation population')

  assert(game.game_type:lower() == "evo", 'game input error: this game should be "evo" but not ' .. game.game_type)
  return game
end

local function read_rep(game)
  -- some rpg based game may not contain strategies
  if not game.strategies then game.strategies = {} end

  -- this is for that format not luaraw
  if type(game.strategies[1]) ~= 'table' then
    local stupid_s = {}
    for i = 2, #game.strategies, 3 do -- !?
      assert(type(game.strategies[i-1]) == 'string' and type(game.strategies[i]) == 'string' and type(game.strategies[i+1]) == 'string', 'invalid strategy define')
      local reg_strs = u.split(game.strategies[i])
      game.strategies[i] = {}
      for _, s in ipairs(reg_strs) do
        local k, v = u.keypairs(s)
        assert((k and v) and k:match("^[%a_]+[%w_]*"), "game input error: invalid upvalue request")
        game.strategies[i][k] = v
      end

      table.insert(stupid_s, {game.strategies[i-1], game.strategies[i], src_sgy_prefix..game.strategies[i+1]})
    end
    game.strategies = stupid_s
  end

  for i, s in ipairs(game.strategies) do
    assert(type(s[1]) == 'string' and type(s[2]) == 'table' and type(s[3]) == 'string', 'invalid strategy define')
    assert(s[2].INIT, 'game define error: strategy '..s[1]..' is lack of INIT')
    game.strategies[i].sgy_label, game.strategies[i].upvalue_req, game.strategies[i].sgy_fun_src = s[1], s[2], src_sgy_prefix..s[3]
    game.strategies[i][1], game.strategies[i][2], game.strategies[i][3] = nil, nil, nil
  end

  if game.states then return read_sg(game) elseif game.init_distri then return read_evo(game) else assert(game.game_type:lower() == "rpg", 'game input error: this game should be "rpg" but not '..game.game_type) end
  return game
end

local function pre_process(game)
  if game.enviroment and #game.enviroment > 0 then
    local env = {}
    for _, s in ipairs(game.enviroment) do
      local k, v = u.keypairs(s)
      assert((k and v) and k:match("^[%a_]+[%w_]*"), "game input error: invalid enviroment request")
      env[k] = v
    end
    game.enviroment = env
  end

  assert(game.value_switch == 0 or game.value_switch == 1, "invalid value switch define")
  assert(game.types and game.action_sets and game.payoffs, "game input error: incompleted game define")

  assert(#game.types > 0, "game input error: invalid types define")
  for i, x in ipairs(game.types) do
    game.types[i] = u.split(x)
    assert(#game.types[i] == 4, "game input error: invalid types define") -- !?
    assert(type(game.types[i][1]) == 'string' and type(game.types[i][2]) == 'number' and type(game.types[i][3]) == 'number' and type(game.types[i][4]) == 'number', 'invalid strategy define')
    game.types[i].type_label, game.types[i].player_num, game.types[i].action_set_idx, game.types[i].payoff_idx = game.types[i][1], game.types[i][2], game.types[i][3], game.types[i][4]
    game.types[i][1], game.types[i][2], game.types[i][3], game.types[i][4] = nil, nil, nil, nil
  end
  assert(#game.action_sets > 0, "game input error: invalid actions define")
  for i, s in ipairs(game.action_sets) do
    game.action_sets[i] = u.split(s)
    assert(#game.action_sets[i] > 0, "game input error: invalid actions define")
  end
  assert(#game.payoffs > 0, "game input error: invalid payoffs define")
  for i, p in ipairs(game.payoffs) do
    if type(p) == "string" then
      game.payoffs[i] = src_pf_prefix .. p
    end
  end
  for _, t in ipairs(game.types) do
    assert(0 < t.action_set_idx and t.action_set_idx <= #game.action_sets and 0 < t.payoff_idx and t.payoff_idx <= #game.payoffs and 0 < t.player_num, 'invalid types define for '..t.type_label)
  end

  if game.strategies or game.init_distri or game.states then
    return read_rep(game)
  end
  assert(game.game_type:lower() == "csg", 'game input error: this game should be "csg" but not ' .. game.game_type)
  return game
end

------------------------------------------------------------------ MOD function
-- Gen a game ini according to content and loader name
function _mod.read(content, ln)
  if type(_mod.loaders[ln:lower()]) == "function" then
    local ok, ret
    ok, ret = pcall(_mod.loaders[ln], content)
    if not ok then
      warn("content load error: bad format data, ", ret:match(".-%:% ([^\n]+)"))
      return nil
    end
    ok, ret = pcall(pre_process, ret)
    if not ok then
      warn(ret:match(".-%:% ([^\n]+)"))
      return nil
    end
    return ret
  else
    warn("content load error: no such loader ", tostring(ln))
    return nil
  end
end

function _mod.serializors.nfg_convertor(game)
  if game.attr.game_type ~= "csg" and game.attr.game_type ~= "evo" and game.attr.game_type ~= "rpg" then
    warn("game type incompatible error: this kind of tool request game type csg/evo/rep, but got ",tostring(game.attr.game_type) ", abandoned")
    return nil
  end
  -- local nfg_file = io.open(game.attr.title .. nfg_ext, 'w')
  local nfg = {}
  -- nfg_file:write(
  --   nfg_prologue:format(game.attr.title, game.attr.comment),
  --   '\n',
  --   nfg_begin,
  --   ' '
  -- )
  table.insert(nfg, nfg_prologue:format(game.attr.title, game.attr.comment))
  table.insert(nfg, "\n")
  table.insert(nfg, nfg_begin)
  for _, player in ipairs(game.players) do
    -- nfg_file:write(('%q'):format(player.label))
    table.insert(nfg, ("%q "):format(player.label))
  end
  -- nfg_file:write(nfg_end, '\n')
  table.insert(nfg, nfg_end)
  table.insert(nfg, nfg_begin)
  for _, p in ipairs(game.players) do
    table.insert(nfg, #(game.action_sets[game.types[p.type].action_set_idx]))
    table.insert(nfg, " ")
  end
  table.insert(nfg, nfg_end)
  table.insert(nfg, "\n")
  -- nfg_file:write(table.concat(game.PAYOFF_MTX, ' '), '\n')
  table.insert(nfg, table.concat(game.PAYOFF_MTX, " "))
  -- nfg_file:close()
  return table.concat(nfg)
end

return _mod
