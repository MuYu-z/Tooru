-- 2019.4.17
-- Project Tooru
-- u

local tablex = require "pl.tablex"
local stringx = require "pl.stringx"
local xclone = require "std.tree".clone

local _mod = {}

-------------------------------------------------------------- Internal function
local function tied_index(_, k, shoe)
  if not shoe[k] then
    return nil
  end
  if type(k) ~= "string" then
    return nil
  end
  if k:sub(1, 1) == "_" then
    return nil
  end
  return shoe[k]
end

-------------------------------------------------------------------- U function
-- Make table readonly, all exist function in lib cannot satisfy me.
function _mod.freeze(t, is_deep)
  if is_deep then
    for k, v in pairs(t) do
      if type(v) == "table" then
        t[k] = _mod.freeze(v, is_deep)
      end
    end
  end
  return tablex.readonly(t)
end

-- may-not-used;
-- Not-deep-accsess contorl, all field in table start with '_' and not a string
-- will be hide for index.
function _mod.tieup(shoe)
  local mt = {
    __index = function(t, k)
      return tied_index(t, k, shoe)
    end,
    __newindex = function(_, _, _)
      error("Attempt to modify asscess controled table")
    end,
    __metatable = false
  }
  return setmetatable({}, mt)
end

-- From lua-user wiki http://lua-users.org/wiki/CopyTable
-- use only first arg
-- change for loop to clear way
-- change to not copy key
-- function _mod.clone(orig, copies)
--   copies = copies or {}
--   local copy
--   if type(orig) == 'table' then
--     if copies[orig] then
--       copy = copies[orig]
--     else
--       copy = {}
--       for orig_key, orig_value in pairs(orig) do
--         copy[orig_key] = _mod.clone(orig_value, copies)
--       end
--       copies[orig] = copy
--     end
--   else -- number, string, boolean, etc
--     copy = orig
--   end
--   return copy
-- end
-- always deep copy without copy metatable.
function _mod.clone(o)
  return xclone(o, true)
end

-- make a string has some prefix every line.
function _mod.beauty(busu, prefix)
  local bijin = prefix .. busu:gsub("\n", "\n" .. prefix)
  if bijin:sub(-(#prefix)) == prefix then
    return bijin:sub(1, -(#prefix + 1))
  else
    return bijin .. "\n"
  end
end

function _mod.split(str)
  if type(str) ~= "string" then -- 兼容toml的同质数组，非同质数组以字符串表现
    return str
  end
  local arr = {}
  for w in str:gmatch("(%S+)%s*") do
    local c = tonumber(w)
    if c then
      w = c
    end
    table.insert(arr, w)
  end
  return arr
end

function _mod.keypairs(str)
  local k, v = str:match("([%w_]+)=(%S+)")
  local c = tonumber(v)
  if c then
    v = c
  end
  return k, v
end

function _mod.decvs(cvs)
  local lines = stringx.splitlines(cvs)
  local items = {}
  for j, l in ipairs(lines) do
    local contents = stringx.split(l, ",")
    if not tonumber(contents[1]) then
      table.insert(items, {TAG = contents[1], table.unpack(contents, 2)})
    else
      table.insert(items, contents)
    end
    contents = items[j]
    for i, c in ipairs(contents) do
      contents[i] = tonumber(c)
    end
  end
  return items
end

-- 鉴于浮点数的蜜汁精度，这里使用近似比较判定没头脑和不高兴的相等关系，小糊涂被用来设置比较
-- 精度，留空使用默认的 1e-12。老糊涂设置相对精度，默认 2.2204460492503131e-16。
-- https://randomascii.wordpress.com/2012/02/25/comparing-floating-point-numbers-2012-edition/
function _mod.stupid_float_eq(meitounao, bugaoxing, xiaohutu, laohutu)
  local relth = laohutu or 2.2204460492503131e-16
  local th = xiaohutu or 1e-12

  local diff = math.abs(meitounao - bugaoxing)
  if diff <= th then
    return true
  end

  meitounao, bugaoxing = math.abs(meitounao), math.abs(bugaoxing)
  if meitounao > bugaoxing then
    return diff <= meitounao * relth
  else
    return diff <= bugaoxing * relth
  end
end

-- Append a list to a list in position
function _mod.append(list, tsil)
  local tail_index = #list
  for j, item in ipairs(tsil) do
    list[tail_index + j] = item
  end
end

return _mod
