-- 2019.5.16
-- Project Tooru
-- top mod

local freezer = require "tooru/u".freeze

----------------------------------------------------------------- Text res load
-- Text loader won't error.
-- If anything is wrong, it just load zh ver. text res.
-- And then print a warning msg.
local textloader =
  loadfile(
  package.searchpath("tooru/res/text", package.path),
  "t",
  {
    pcall = pcall,
    dofile = dofile,
    string = string,
    select = select,
    tostring = tostring,
    stderr = io.stderr
  }
)
local para = _G.args or _ENV.args or {lang = "zh"}
local lang = para.lang or para.language
local text = textloader(lang or "zh")
_G.TOORU_TEXT = freezer(text)

return freezer(
  {
    ------------------------------------------------------------------ Sub mod
    reader = require "tooru/fp",
    render = require "tooru/render",
    serializors = require "tooru/fp".serializors,
    game = require "tooru/game",
    calculator = require "tooru/solver",
    ------------------------------------------------------------------------ ATTR
    VERSION = "0.1",
    NAME = "Tooru"
  },
  true
)
