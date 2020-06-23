-- 2019.4.17
-- Project Tooru
-- Load string file (lua)

local ok, text = pcall(dofile, "tooru/res/text." .. select(-1, ...) .. ".txt")
if not ok then
  warn("text res load warning: no ", tostring(select(-1, ...)), " res and loading zh ver. res")
  text = dofile("tooru/res/text.zh.txt")
end

text.gt_version = "0.2"

text.gt_copyright =
  ("Gametracer %s %s, %s (C) 2002, Ben Blum and Christian Shelton"):format(
  text.version,
  text.gt_version,
  text.copyright
)

text.banner = {}
text.banner.gnm =
  ("Gametracer %s - gnm, %s.\n%s.\n%s"):format(
  text.game_solve_tool,
  text.gnu_gpl,
  text.gt_copyright,
  text.gnne
)

return text
