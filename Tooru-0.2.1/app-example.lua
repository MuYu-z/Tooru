-- 2019.9.2
-- Project Tooru
-- tooru application
warn '@on'

-- render and solver setting
local game2solver = {csg = 'ipa', evo = 'ipa'}

-- u
local function nothing()
  return
end
local function cook(raw)
  local dish = {}
  if raw == '' then
    return nil, 'nothing to fire'
  end
  for fish in raw:gmatch('%s*([%w%.%,%{%}]+)') do
    local good, msg = load('return ' .. fish, 'user input', 't', {})
    if not good then
      return nil, 'cannot read outcome: ' .. msg
    end
    local ok, cooked = pcall(good)
    if not ok then
      return nil, cooked:match('.-%:% ([^\n]+)')
    end
    table.insert(dish, cooked)
  end
  return table.unpack(dish)
end

-- parse args
local USAGE =
  [[
Project Tooru, we make some calculation for world.
  -l, --language (default 'en')          Language.
  -f, --format   (default 'luaraw')      Game-define format.
  -o, --output   (default stdout)        Program infomation output file.
  -i, --input    (default stdin)         Program command input file.
  -d, --outdata  (default 'null')        Game analyze data to the file path.
  -q, --quiet                            Be quiet!
  <game_path>    (default 'game.luaraw') Path to the game-define file.
]]
local args = require 'pl.lapp'(USAGE)
_G.args = args

-- check game file
local good, msg = io.open(args.game_path)
if not good then
  io.stderr:write('cannot read the file on game_path: ', msg, '\n', USAGE)
  os.exit(1)
end
local ini_f = good
io.input(args.input)
io.output(args.output)
if args.quiet then
  io.output(io.tmpfile())
end
if args.outdata ~= 'null' then
  good, msg = io.open(args.outdata, 'w')
  if not good then
    io.stderr:write('cannot creat outdata file: ', msg, '\n')
    os.exit(1)
  end
else
  if os.getenv('OS') == 'Windows_NT' then
    good = io.open('nul', 'w')
  else
    good = io.open('/dev/null', 'w')
  end
end
local doutput = good

-- load tooru mod & others mod
local tooru = require 'tooru'

-- initialize game
good = tooru.reader.read(ini_f:read('a'), args.format)
if not good then
  os.exit(2)
end
local defined = good
good = tooru.game.new(defined)
if not good then
  os.exit(2)
end
local game = good
local sname = game2solver[game.attr.game_type]
ini_f:close()

-- some simple game report and static analyze will go first
local sub_report = {evo = nil, csg = nothing}
function sub_report.evo()
  if game.attr.simulation_population == 0 then
    io.write 'Due to Evolution setting, there is no need to get simulation ready.\n'
    return
  end
  io.write(
    ('The simulation for Evolution will be set up in %d population with %f selection intensity and %f mutations intensity.\n'):format(
      game.attr.simulation_population,
      game.attr.selection_intensity,
      game.attr.mutations_intensity
    ),
    'Initial choice distribution:\n'
  )
  for i = 1, #game.actions do
    -- 0 is the index of initial record
    io.write(
      game.historys:req(0, 'd', i),
      ' individuals choose ',
      game.actions[i].label,
      ', their group fitness is ',
      game.historys:req(0, 'f', i),
      ', homogenization prob. is ',
      game.init_chance[i],
      '.\n'
    )
  end
  io.write('Average fitness is ', game.historys:req(0, 'f', 'avg'), '.\n')
end

local function report()
  local ne_render =
    tooru.render.new('outcome', 'human_read', io.output(), true, 3, true)
  local ne_solver = tooru.calculator.new(sname, {ne_render})
  local vj = ''
  if game.attr.value_switch == 0 then
    vj = 'not '
  end
  io.write('Auto generated text; Project Tooru; ', os.date(), '\n')
  io.write(
    ('This is a simple summon of %s (%s) game %q, which is considered with %q.\n'):format(
      game.attr.type_name,
      game.attr.game_type,
      game.attr.title,
      game.attr.comment
    ),
    ('This game contains %d Players assgined with %d Types. All of they share a Action Set with %d elements.\n'):format(
      #game.players,
      #game.types,
      #game.actions
    ),
    ('The Payoff MTX totaly contains %d elements. Original action defination is %svalue sensitive. Overall payoff is supported by %d specific payoff defination(s).\n'):format(
      #game.PAYOFF_MTX,
      vj,
      #game.payoffs
    ),
    'You can find more details in your very own game-define file, game serializors generated content (command used), or other command generated content (which you may use below).\n'
  )
  io.write 'Equilibrium Calcularion (some stochastic algorithms may gen vary results each time)...\n'
  good = ne_solver:solve(game)
  if not good then warn 'unexpected error raised durring NE solving' end
  sub_report[game.attr.game_type]()
  io.write 'This is the end of report.\n'
end
local _ = (not args.quiet) and report()

-- define command function
local undo_map = {
  addplayer = 'delplayer',
  delplayer = 'addplayer'
}
local dodo = {}
local time_on_timeline, end_of_the_time = 0, 0
local exec = {
  -- some common command
  reset = nil,
  report = report,
  undo = nil,
  redo = nil,
  clear = nil,
  -- nash
  isnash = nil,
  br = nil,
  nash = nil
}
function exec.reset()
  dodo = {}
  time_on_timeline, end_of_the_time = 0, 0
  game = tooru.game.new(defined)
  io.write 'Reset done!\n'
end

function exec.undo()
  if time_on_timeline == 0 then
    return 'no more'
  end
  local dd = dodo[time_on_timeline]
  exec[undo_map[dd[1]]](dd[2])
  time_on_timeline = time_on_timeline - 1
  io.write('Undo command: "', dd[1], ' ', dd[2], '"\n')
end

function exec.redo()
  if time_on_timeline == end_of_the_time then
    return 'no more'
  end
  time_on_timeline = time_on_timeline + 1
  local dd = dodo[time_on_timeline]
  exec[dd[1]](dd[2])
  io.write('Redo command: "', dd[1], ' ', dd[2], '"\n')
end

function exec.clear()
  if type(game.reset) == 'function' then
    game:reset()
    io.write 'Historys record cleared!\n'
  else
    io.write 'Nothing to clear.\n'
  end
end

-- some really functionality function
local _is_nash_teacher = tooru.calculator.quick_simple_naive_new('is_nash')
function exec.isnash(outcome_raw)
  good, msg = cook(outcome_raw)
  if not good then
    return msg
  end
  good = _is_nash_teacher:solve(game, good)
  if type(good) == 'boolean' then
    io.write(tostring(good), '\n')
  else
    return 'command error, see warning msg'
  end
end
if not _is_nash_teacher then
  warn '"isnash" is unavilible'
  exec.isnash = function () return 'this command is unavilible' end
end
local _br_renders = {
  tooru.render.new('strategy', 'human_read', io.output()),
  tooru.render.new('strategy', 'raw', doutput)
}
local _br_teacher = tooru.calculator.new('best_response', _br_renders)
function exec.br(choices_raw)
  good, msg = cook(choices_raw)
  if not good then
    return msg
  end
  good = _br_teacher:solve(game, good, msg)
  if not good then return 'command error, see warning msg' end
end
if #_br_renders ~= 2 or not _br_teacher then
  warn '"br" is unavilibe'
  exec.br = function () return 'this command is unavilible' end
end
local _nash_renders = {
  tooru.render.new('outcome', 'human_read', io.output()),
  tooru.render.new('outcome', 'raw', doutput)
}
local _nash_teacher = tooru.calculator.new(sname, _nash_renders)
function exec.nash()
  good = _nash_teacher:solve(game)
  if not good then return 'command error, see warning msg' end
end
if #_nash_renders ~= 2 or not _nash_teacher then
  warn '"nash" is unavilibe'
  exec.nash = function () return 'this command is unavilible' end
end

-- dive into main loop
local exit = false
local errmsg
local ln = 0
io.write 'Now into the analyze process. Input will be read from stdin or your pre-defined script, every single command must end with "\\n". Command details refer to the man-book.\n'
while not exit do
  local input = io.read()
  if not input then
    io.write('EOF of input revived, quit.')
    break
  end
  ln = ln + 1

  local cmd, para = input:match('^%s*([%w_]+)%s*()')
  if not cmd then
    errmsg = nil
  elseif cmd == 'quit' or cmd == 'exit' then
    errmsg = nil
    exit = true
  elseif not exec[cmd] then
    errmsg = ('undefined command in line #%d: %s'):format(ln, cmd)
  else
    para = input:sub(para)
    errmsg = exec[cmd](para)
    if (not errmsg) and undo_map[cmd] then
      time_on_timeline = time_on_timeline + 1
      end_of_the_time = time_on_timeline
      dodo[end_of_the_time] = {cmd, para}
    end
  end

  if errmsg then
    io.stderr:write(errmsg, '\n')
  end
end
