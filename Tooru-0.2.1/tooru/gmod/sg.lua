-- 2019.11.19
-- Project Tooru
-- Stochastic game

local rpg = require "tooru/gmod/rpg"

local _mod = {
  WHO = "Stochastic Game",
  SERIALIZORS = {},
  TYPE = "sg"
}

----------------------------------------------------------------- INIT function
local function init(game, ini)
  return game
end

------------------------------------------- MOD function - stochastic-game obj.
function _mod.new(ini)
  ---------------------------------------------------- *** SG Game instance ***
  local good, msg = rpg.new(ini)
  if not good then
    return nil, msg
  end
  good.status = {}
  good.transforms = {}
  ---------------------------------------------------- *** SG Game instance ***
  return init(good, ini)
end

return _mod
