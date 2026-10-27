--[[
Convert START/END marker pairs into regions.

Looks at every project marker (not regions) named like:
    Region name  -  START
    Region name - END
(case-insensitive; spacing around the dash does not matter). For each pair
with the same name it
  * deletes the two markers,
  * inserts a region spanning START -> END, named "Region name"
    (the text before the last " - START" / " - END"), and
  * keeps the START marker's color.

Markers are paired in time order per name: each END is matched with the
nearest earlier unmatched START of the same name, so repeated names work.
Unpaired START/END markers are left untouched and listed in the report.
A confirmation dialog is shown before anything is changed, and the whole
operation is a single undo step.
]]

local proj = 0
local TITLE = "Markers to regions"
local undo_open = false

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Returns base_name, "start"|"end" for names like "Song  -  START", else nil.
local function parse_marker_name(name)
  local lower = name:lower()
  local base_lower, kind = lower:match("^(.-)%s*%-%s*(%a+)%s*$")
  if not base_lower or (kind ~= "start" and kind ~= "end") then return nil end
  -- Same length as the lowercase capture, but with the original casing.
  local base = trim(name:sub(1, #base_lower))
  if base == "" then return nil end
  return base, kind
end

local function collect_markers()
  local list = {}
  local idx = 0
  while true do
    local retval, is_region, pos, _, name, number, color =
      reaper.EnumProjectMarkers3(proj, idx)
    if retval == 0 then break end
    if not is_region then
      local base, kind = parse_marker_name(name)
      if base then
        list[#list + 1] = {
          base = base, kind = kind, pos = pos,
          number = number, color = color, name = name
        }
      end
    end
    idx = idx + 1
  end
  -- Time order; at the same position START comes before END.
  table.sort(list, function(a, b)
    if a.pos ~= b.pos then return a.pos < b.pos end
    if a.kind ~= b.kind then return a.kind == "start" end
    return a.number < b.number
  end)
  return list
end

local function find_pairs(markers)
  local open = {}   -- base name -> stack of unmatched START markers
  local pairs_found, unpaired = {}, {}

  for _, m in ipairs(markers) do
    if m.kind == "start" then
      open[m.base] = open[m.base] or {}
      table.insert(open[m.base], m)
    else
      local stack = open[m.base]
      local s = stack and table.remove(stack)
      if s and m.pos > s.pos then
        pairs_found[#pairs_found + 1] = { start = s, finish = m }
      else
        -- END with no usable START (or a zero-length pair).
        if s then table.insert(stack, s) end
        unpaired[#unpaired + 1] = m
      end
    end
  end

  for _, stack in pairs(open) do
    for _, s in ipairs(stack) do unpaired[#unpaired + 1] = s end
  end
  return pairs_found, unpaired
end

local function main()
  local markers = collect_markers()
  if #markers == 0 then
    reaper.MB("No START/END markers were found.", TITLE, 0)
    return
  end

  local found, unpaired = find_pairs(markers)
  if #found == 0 then
    reaper.MB("No matching START/END pairs were found.", TITLE, 0)
    return
  end

  local lines = {}
  for _, p in ipairs(found) do
    lines[#lines + 1] = string.format("- %s  (%.3f s -> %.3f s)",
      p.start.base, p.start.pos, p.finish.pos)
  end
  local msg = string.format("%d pair(s) will be converted to regions:\n\n%s",
    #found, table.concat(lines, "\n"))
  if #unpaired > 0 then
    local u = {}
    for _, m in ipairs(unpaired) do u[#u + 1] = "- " .. m.name end
    msg = msg .. string.format("\n\n%d unpaired marker(s) will be left alone:\n\n%s",
      #unpaired, table.concat(u, "\n"))
  end
  msg = msg .. "\n\nProceed?"

  if reaper.MB(msg, TITLE, 4) ~= 6 then return end -- 6 = Yes

  reaper.Undo_BeginBlock()
  undo_open = true
  reaper.PreventUIRefresh(1)

  local created = 0
  for _, p in ipairs(found) do
    reaper.DeleteProjectMarker(proj, p.start.number, false)
    reaper.DeleteProjectMarker(proj, p.finish.number, false)
    reaper.AddProjectMarker2(proj, true, p.start.pos, p.finish.pos,
      p.start.base, -1, p.start.color or 0)
    created = created + 1
  end

  reaper.PreventUIRefresh(-1)
  reaper.UpdateTimeline()
  reaper.Undo_EndBlock(TITLE .. ": " .. created .. " region(s) created", -1)
  undo_open = false

  reaper.MB(string.format("Created %d region(s).", created), TITLE, 0)
end

local ok, err = xpcall(main, debug.traceback)
if not ok then
  reaper.PreventUIRefresh(-1)
  if undo_open then reaper.Undo_EndBlock(TITLE .. " (failed)", -1) end
  reaper.MB("Markers to regions failed:\n\n" .. tostring(err), TITLE, 0)
end
