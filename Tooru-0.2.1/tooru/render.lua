-- 2019.6.6
-- Project Tooru
-- Game analysis result render

local tablex = require "pl.tablex"
local pp = require "pl.pretty"
local u = require "tooru/u"

--------------------------------------------------------------------------- MOD
local _mod = {
  -- What can we rendering?
  NAME = {
    "payoff",
    "strategy",
    "outcome",
    "evo_historys",
    "simple"
  },
  -- What format can we output?
  TYPE = {"csv", "raw", "human_read", "plt"}
}

-------------------------------------------------------- Internal used formatter
local formater = {
  raw = nil,
  csv = nil,
  human_read = nil,
  plt = nil
}

-- formater's comment prefix
local comment_prefix = {
  raw = "-- ",
  plt = "# ",
  human_read = "",
  csv = "COMMENT: "
}

function formater.raw(yuubin)
  return pp.write(yuubin) .. "\n"
end

function formater.csv(yuubin, sp)
  local content = {}
  if type(yuubin) == "string" then
    warn 'csv formater just recive a string, return back'
    return yuubin
  elseif type(yuubin) ~= "table" then
    warn 'cannot handle input data, only "list" or formated "string" is valid'
    return nil
  end
  sp = sp or '\t'
  if type(sp) ~= 'string' then
    warn 'invalid split string for csv, using \\t'
    sp = '\t'
  end

  for i, e in ipairs(yuubin) do
    if (type(e) == "number") or (type(e) == "string") then
      content[i] = e
    elseif type(e) ~= "table" then
      warn 'cannot handle input data item, only "list", "string", or "number" is valid'
      return nil
    end
    content[i] = table.concat(e, sp)
  end
  -- we need this '' at the end of 'content' list, or we will suffer the
  -- too looooooooooooooooooooooooooooong a single line
  table.insert(content, "")
  return table.concat(content, "\n")
end

-- yuubin construct format refer to 'data_processor.outcome'
-- this formater usully format outcome-like data
function formater.human_read(yuubin)
  local content = {}
  table.insert(content, ("Total %d %s(s) generated by %q.\n"):format(#yuubin, yuubin.TYPE, yuubin.SOURCE))
  for i, o in ipairs(yuubin) do
    if o.NAME then
      table.insert(content, ("%s #%d is a represent of %q:\n"):format(yuubin.TYPE, i, o.NAME))
    else
      table.insert(content, ("%s #%d:\n"):format(yuubin.TYPE, i))
    end
    for _, oo in ipairs(o) do
      table.insert(content, oo.LABEL .. ": ")
      for _, oio in ipairs(oo) do
        local prob = "pure"
        if oio.prob < 1.0 then
          prob = tostring(oio.prob)
        end
        table.insert(content, ("%s(%s)"):format(oio.LABEL, prob))
        table.insert(content, ", ")
      end
      table.remove(content)
      table.insert(content, "\n")
    end
  end
  return table.concat(content)
end

-- plt formater need a list of data, which the item of this data list is
-- also a list, which contains a bunch of actul data items. plt formater will
-- write one item of data list in a line, and then write all items of a line
-- split with a whitespace
-- otherwise pre-formated string is also acceptable. and one item can be a
-- single number or string
function formater.plt(yuubin)
  return formater.csv(yuubin)
end

-------------------------------------------------------- Internal used porcessor
local data_processor = {
  evo_historys = function (data) return data end,
  outcome = nil,
  strategy = nil
}

-- this return things really complex
-- ret = {TYPE, SOURCE, [1], [2], ...} the list of all outcome data
-- [item] = {NAME, [1], [2], ...} the list of players' (in global players index)
--                                mixed_choice of single outcome data
-- [iitteemm] = {LABEL, [1], [2], ...} the list of actions' prob.
--                                     (in local actions index)
--                                     of single player of single outcome data
-- [iiittteeemmm] = {LABEL, prob.} the prob. of a certain action of
--                                 a certain player of a certain outcome data
function data_processor.outcome(data, game)
  local ret = {TYPE = "outcome", SOURCE = data.SOURCE}
  local gtypes, gactions, gaction_sets = game.types, game.actions, game.action_sets
  for i, o in ipairs(data) do
    local item = {NAME = o.TAG}
    local progress = 1
    local is_mixed = math.type(o[1]) == "float"
    for pi, p in ipairs(game.players) do
      local t = gtypes[p.type]
      item[pi] = {
        LABEL = p.label
      }
      local iitteemm = item[pi]
      if is_mixed then
        -- this situation is for mixed outcome
        for _, gai in ipairs(gaction_sets[t.action_set_idx]) do
          if o[progress] > 0.0 then
            table.insert(
              iitteemm,
              {
                LABEL = gactions[gai].label,
                prob = o[progress]
              }
            ) -- iiittteeemmm
          end
          progress = progress + 1
        end
      else
        -- this situation is for outcome
        table.insert(
          iitteemm,
          {
            LABEL = gactions[gactions[t.action_set_idx][o[progress]]].label,
            prob = 1.0
          }
        ) -- iiittteeemmm
        progress = progress + 1
      end
    end
    assert(progress - 1 == #o, "length of outcome wrong")
    ret[i] = item
  end
  return ret
end

--  strategy is something outcome-like data type, so this function's return
--  refer to above function comment. But strategy does not contain muti-players.
function data_processor.strategy(data, game)
  local ret = {TYPE = "strategy", SOURCE = data.SOURCE}
  local gtypes, gplayers, gactions, gaction_sets = game.types, game.players, game.actions, game.action_sets
  for i, o in ipairs(data) do
    local item = {
      NAME = ("%s's %s, with %f payoff"):format(gplayers[o.TARGET].label, o.TAG, o.BR_PAYOFF)
    }
    -- Just single player, so it is just item[1].
    item[1] = {LABEL = gplayers[o.TARGET].label}
    if math.type(o[1]) == "float" then
      -- this situation is for some mixed
      for lai, gai in ipairs(gaction_sets[gtypes[gplayers[o.TARGET].type].action_set_idx]) do
        if o[lai] > 0.0 then
          table.insert(
            item[1],
            {
              LABEL = gactions[gai].label,
              prob = o[lai]
            }
          )
        end
      end
    else
      -- this situation is for some action list
      for _, br_lai in ipairs(o) do
        table.insert(
          item[1],
          {
            LABEL = gactions[br_lai].label,
            -- 1.0 stand for 'pure', br can be consist by any br's element
            -- so this 'pure' just list all br's element
            prob = 1.0
          }
        )
      end
    end
    ret[i] = item
  end
  return ret
end

------------------------------------------------- Export function for new render
------------------------------------------------ *** Render instance (2/2) ***
local _ex = {
  banner = nil,
  write = nil,
  flush = nil,
  close = nil
}
------------------------------------------------ *** Render instance (2/2) ***

-- Write some banner to the file, banana is a banner string, but the string
-- written to file is with comment prefix.
function _ex:banner(banana)
  if not self.attr.is_banner then
    return self
  end
  local good, msg =
    self.FILE:write(
    ("%sProject Tooru Game Calc Doc\n%s%s\n%sThis doc reperesent a %s.\n%s"):format(
      comment_prefix[self.TYPE],
      comment_prefix[self.TYPE],
      os.date(),
      comment_prefix[self.TYPE],
      self.NAME,
      -- beauty will auto append a '\n'
      u.beauty(banana, comment_prefix[self.TYPE])
    )
  )
  return good and self, msg
end

-- Write function will handle the genenric answer to the something can be
-- directly format to a certain format string. And make it in line to be
-- eventully written.
function _ex:write(...)
  local good = data_processor[self.NAME](...)
  if not good then
    return nil, 'invalid data for this render'
  end
  table.insert(self._wait, good)
  if self.attr.is_ins then
    return self:flush()
  end
  return self
end

-- flush function will actully format the answer instance to a string and
-- write it to the file.
function _ex:flush()
  for _, ant in ipairs(self._wait) do
    local good = formater[self.TYPE](ant)
    if not good then
      return nil, 'invalid data for this render type'
    end
    if not (self.FILE:write(good) and self.FILE:flush()) then
      return nil, "render write error: cannot write to file"
    end
  end
  self._wait = {}
  return self
end

-- attr must checked before
function _ex:plot(data_fn, plt_script_fn, pic_fn, terms, attr)
  local good, msg = io.open(data_fn, "w")
  if not good then
    return nil, msg
  end
  local data_f = good

  for _, ant in ipairs(self._wait) do
    good = formater.plt(ant)
    if not good then
      data_f:close()
      return nil, 'invalid data for this render type'
    end
    good, msg = data_f:write(good)
    if not good then
      data_f:close()
      return nil, msg
    end
  end
  data_f:close()

  -- gen write script
  good, msg = io.open(plt_script_fn, "w")
  if not good then
    return nil, msg
  end
  -- first set something common
  attr = attr or {}
  good:write "reset\n"
  if attr.grid then
    good:write "set grid\n"
  end
  good:write("set terminal ", attr.ext or "svg", " size ", attr.width or 720, ",", attr.heigh or 480, "\n")
  good:write("set output ", '"', pic_fn, '"\n')
  if attr.key_pos == false then
    good:write "unset key\n"
  else
    good:write("set key ", attr.key_pos or "top left", "\n")
  end
  if "table" == type(attr.xrange) and #attr.xrange == 2 then
    good:write("set xrange [", attr.xrange[1], ":", attr.xrange[2], "]\n")
  end
  if "table" == type(attr.yrange) and #attr.yrange == 2 then
    good:write("set yrange [", attr.yrange[1], ":", attr.yrange[2], "]\n")
  end
  good:write('set xlabel "time"\n')
  if attr.vlabel then
    good:write('set ylabel "', attr.vlabel, '"\n')
  end
  if attr.title then
    good:write('set title "', attr.title, '"\n')
  end
  -- and then plot data
  local fn_using = ' "' .. data_fn .. '" using 0:'
  local ti_map, it_map = table.unpack(self._plot_aux)
  terms = terms or it_map
  good:write("plot")
  if type(terms[1]) == "number" then
    for _, i in ipairs(terms) do
      if not it_map[i] then
        return nil, "plot error: invalid term number " .. i
      end
      good:write(fn_using, i, ' w l title "', it_map[i], '",')
    end
  else
    for _, t in ipairs(terms) do
      if not ti_map[t] then
        return nil, "plot error: invalid term " .. t
      end
      good:write(fn_using, ti_map[t], ' w l title "', t, '",')
    end
  end
  good:close()

  local ok = os.execute("gnuplot " .. plt_script_fn:gsub(" ", "\\ "))
  return ok and self, not ok and "plot error: fire gnuplot failed, check stderr"
end

function _ex:close()
  return self.FILE:close()
end

------------------------------------------------------------------ MOD function
function _mod.new(name, format, file, is_ins, precision, is_banner)
  if type(file) == "string" then
    local good, msg = io.open(file, "w")
    if not good then
      warn("render cannot open file: ", msg)
      return nil
    end
    file = good
  end
  if io.type(file) ~= 'file' then
    warn ("render initialization error: not a output file for ", tostring(file), " which is ", tostring(io.type(file)))
    return nil
  end
  if not tablex.find(_mod.NAME, name) then
    warn("render initialization error: no such render for ", tostring(name))
    return nil
  end
  if not tablex.find(_mod.TYPE, format) then
    warn("render initialization error: no such render with ", tostring(format), " format")
    return nil
  end
  if name == "simple" and format ~= "raw" then
    warn 'render warning: simple render casted to "raw" format'
    format = "raw"
  end

  ------------------------------------------------ *** Render instance (1/2) ***
  return tablex.merge(
    {
      TYPE = format,
      NAME = name,
      FILE = file,
      attr = {
        is_ins = is_ins or true,
        precision = precision or 6,
        is_banner = is_banner or false
      },
      _wait = {}
    },
    _ex,
    true
  )
  ------------------------------------------------ *** Render instance (1/2) ***
end

return _mod