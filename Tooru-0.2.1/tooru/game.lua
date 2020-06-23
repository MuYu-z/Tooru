-- 2019.5.17
-- Project Tooru
-- game dispatcher

local _mod = {}

function _mod.new(ini)
  if type(ini.game_type) ~= "string" then
    warn "input error: invalid game define"
    return nil
  end
  local ok, game_mod = pcall(require, "tooru/gmod/" .. ini.game_type)
  if not ok then
    warn("game mod loading error: no mod for game type ", tostring(ini.game_type))
    return nil
  end

  local game = game_mod.new(ini)
  if not game then return nil end
  if #game_mod.SERIALIZORS > 0 then
    game.CONTENT = require "tooru/fp".serializors[game_mod.SERIALIZORS[1]](game)
    assert(
      game.CONTENT,
      ("game content serialize failed; game type: %s; game mod: %s"):format(ini.game_type, game_mod.WHO)
    )
  end
  game.attr.type_name = game_mod.WHO
  return game
end

return _mod
