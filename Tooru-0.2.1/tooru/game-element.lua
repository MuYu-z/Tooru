-- 2019.4.17
-- Project Tooru
-- Game element

local _mod = {}

------------------------------------------------------------------ MOD function
------------------------------------------------------------------ PLAYER
function _mod.Player(label, type, payoff)
  return {
    label = label,
    type = type,
    payoff = payoff
  }
end

------------------------------------------------------------------ TYPE
function _mod.Type(label, action_set_idx, payoff_idx)
  return {
    label = label,
    action_set_idx = action_set_idx,
    payoff_idx = payoff_idx
  }
end

------------------------------------------------------------------ ACTION
function _mod.Action(label, value)
  return {label = label, value = value}
end

------------------------------------------------------------------ STRATEGY
function _mod.Strategy(label, reg, func)
  return {
    label = label,
    func = func,
    reg = reg
  }
end

------------------------------------------------------------------ CACHE
-- function _mod.Cache()
--   local new_cache = {}
--   function new_cache:checkin(path, ret)
--     local p = self
--     for i = #path, 2, -1 do
--       if not p[path[i]] then
--         p[path[i]] = {}
--       end
--       p = p[path[i]]
--     end
--     p[path[1]] = ret
--   end
--   function new_cache:checkout(path)
--     local p = self
--     for i = #path, 2, -1 do
--       p = p[path[i]]
--       if type(p) ~= 'table' then
--         return nil
--       end
--     end
--     return p[path[1]]
--   end
--   return new_cache
-- end

return _mod
