--[[
Export each REAPER region as a standalone MIDI file containing:
  * a tempo and time-signature event at the start (START_TEMPO_TICK, default 0)
  * Text events at tick 0 and at the region's last tick
  * tempo/time-signature markers inside the region
  * project markers inside the region
  * an end-of-track event at the region's exact musical length

Output:
  BASE_DIR / region_name / chosen-name.mid

Behaviour:
  * The start tempo/time signature comes from a tempo marker located within
    START_MARKER_THRESHOLD_SEC of the region start (before or after). If there
    is none, the underlying tempo/time signature at the region start is used.
  * Existing .mid files are overwritten.
  * The extension is always lower-case ".mid" (any extension typed in the
    filename prompt is stripped first).
  * The project is not modified.

Notes:
  * MIDI tempo events are step changes. REAPER's gradual/linear tempo ramps
    cannot be represented exactly by a finite set of MIDI tempo events, so a
    region containing ramps will differ slightly in real time.
  * Positions are quantized to PPQ ticks.
  * Regions sharing the same name share an output folder, so the later one
    overwrites the earlier one.
]]

-- ========================= USER CONFIGURATION =============================
local DEFAULT_BASE_DIR = reaper.GetProjectPath("") .. "/tempo-map-export"
local DEFAULT_TEMPO_MAP_NAME = "tempo-map"
local PPQ = 960
-- A tempo marker within this many seconds of the region start (before or
-- after) is treated as "the" start tempo marker.
local START_MARKER_THRESHOLD_SEC = 0.1
-- Boundary events: a MIDI Text event (meta 0x01) is written at tick 0 and at
-- the last tick of the region, so the file spans the full region length and
-- the importer has events at both ends. Text events do not create project
-- markers. Use "" to disable either one; "%name" expands to the region name.
local START_EVENT_TEXT = "%name start"
local END_EVENT_TEXT = "%name end"
-- Tick at which the start tempo/time signature is written. Tick 0 is avoided
-- on purpose: REAPER treats a tempo at tick 0 as the file's initial tempo and
-- may not create a marker for it. 1 tick is musically negligible (1/960 beat);
-- the Text event keeps tick 0 occupied so the clip still starts at the region
-- start. Set to 0 to write at tick 0 like a normal MIDI file.
local START_TEMPO_TICK = 0
-- Write a tempo event at the region's last tick, equal to the last tempo in
-- effect inside the region. This gives every file at least two tempo events,
-- which REAPER needs in order to import the tempo map when files are dragged in.
local ADD_END_TEMPO = true
-- Print what start tempo/time signature each region used to REAPER's console.
local LOG_TO_CONSOLE = true
-- ==========================================================================

local proj = 0

local function prompt_value(title, caption, default)
  local ok, value = reaper.GetUserInputs(title, 1, caption, default)
  if not ok then return nil end
  value = value:gsub("^%s+", ""):gsub("%s+$", "")
  if value == "" then return default end
  return value
end

local function sanitize_component(s)
  s = s:gsub("[/\\:%*%?\"<>|]", "_")
  s = s:gsub("[%c]", "_")
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  s = s:gsub("[%. ]+$", "")
  if s == "" or s == "." or s == ".." then s = "unnamed" end
  return s
end

-- Removes a trailing ".mid" typed by the user in any case (".MID", ".Mid"...),
-- so the final name is always "<name>.mid".
local function strip_mid_extension(s)
  while s:lower():sub(-4) == ".mid" do
    s = s:sub(1, -5)
  end
  return s
end

local function join_path(a, b)
  if a:sub(-1) == "/" or a:sub(-1) == "\\" then
    return a .. b
  end
  return a .. "/" .. b
end

local function mkdir(path)
  return reaper.RecursiveCreateDirectory(path, 0) >= 0
end

local function u16be(n)
  n = math.floor(n) % 65536
  return string.char(math.floor(n / 256), n % 256)
end

local function u32be(n)
  n = math.floor(n) % 4294967296
  return string.char(
    math.floor(n / 16777216) % 256,
    math.floor(n / 65536) % 256,
    math.floor(n / 256) % 256,
    n % 256
  )
end

local function vlq(n)
  n = math.max(0, math.floor(n + 0.5))
  local bytes = { n % 128 }
  n = math.floor(n / 128)
  while n > 0 do
    table.insert(bytes, 1, (n % 128) + 128)
    n = math.floor(n / 128)
  end
  local out = {}
  for i = 1, #bytes do out[i] = string.char(bytes[i]) end
  return table.concat(out)
end

local function meta_event(kind, payload)
  return string.char(0xFF, kind) .. vlq(#payload) .. payload
end

local function tempo_micros(bpm)
  if not bpm or bpm <= 0 then bpm = 120 end
  local micros = math.floor(60000000 / bpm + 0.5)
  return math.max(1, math.min(0xFFFFFF, micros))
end

local function tempo_event(bpm, extra_micros)
  local micros = tempo_micros(bpm) + (extra_micros or 0)
  micros = math.max(1, math.min(0xFFFFFF, micros))
  return meta_event(0x51, string.char(
    math.floor(micros / 65536) % 256,
    math.floor(micros / 256) % 256,
    micros % 256
  ))
end

local function timesig_event(num, den)
  num = math.max(1, math.min(255, math.floor(num or 4)))
  den = math.max(1, math.floor(den or 4))
  local power = 0
  while (2 ^ power) < den and power < 7 do power = power + 1 end
  -- MIDI encodes the denominator as log2(denominator).
  return meta_event(0x58, string.char(num, power, 24, 8))
end

local function text_event(text)
  return meta_event(0x01, text or "")
end

local function marker_event(name)
  return meta_event(0x06, name or "")
end

local function write_midi(path, events, end_tick)
  table.sort(events, function(a, b)
    if a.tick ~= b.tick then return a.tick < b.tick end
    return a.order < b.order
  end)

  local track = {}
  local previous_tick = 0
  for _, ev in ipairs(events) do
    -- Nothing may sit past the end of the region.
    local tick = math.min(math.max(previous_tick, ev.tick), end_tick)
    track[#track + 1] = vlq(tick - previous_tick)
    track[#track + 1] = ev.data
    previous_tick = tick
  end

  -- End-of-track lands exactly at the region's length.
  track[#track + 1] = vlq(end_tick - previous_tick)
  track[#track + 1] = string.char(0xFF, 0x2F, 0x00)

  local track_data = table.concat(track)
  local header = "MThd" .. u32be(6) .. u16be(0) .. u16be(1) .. u16be(PPQ)
  local chunk = "MTrk" .. u32be(#track_data) .. track_data

  -- Overwrite any existing file: remove it first (ignore "doesn't exist"),
  -- then create it fresh in binary mode.
  os.remove(path)
  local f, err = io.open(path, "wb")
  if not f then return false, err end
  local ok, write_err = f:write(header, chunk)
  if not ok then
    f:close()
    return false, write_err
  end
  local close_ok, close_err = f:close()
  if not close_ok then return false, close_err end
  return true
end

local function tick_at_time(t, start_qn)
  local qn = reaper.TimeMap2_timeToQN(proj, t) - start_qn
  return math.max(0, math.floor(qn * PPQ + 0.5))
end

local function collect_markers(start_time, end_time, start_qn, events)
  local idx = 0
  while true do
    local retval, is_region, pos, region_end, name =
      reaper.EnumProjectMarkers3(proj, idx)
    if retval == 0 then break end

    if not is_region and pos >= start_time - 1e-9 and pos < end_time - 1e-9 then
      events[#events + 1] = {
        tick = tick_at_time(pos, start_qn),
        order = 4,
        data = marker_event(name)
      }
    end
    idx = idx + 1
  end
end

-- Returns the tempo marker closest to the region start within the threshold
-- (or nil). Markers slightly before the start count as well.
local function find_start_marker(start_time)
  local best, best_dist
  local count = reaper.CountTempoTimeSigMarkers(proj)
  for i = 0, count - 1 do
    local ok, timepos, _, _, bpm, num, den = reaper.GetTempoTimeSigMarker(proj, i)
    if ok then
      local dist = math.abs(timepos - start_time)
      if dist <= START_MARKER_THRESHOLD_SEC and (not best or dist < best_dist) then
        best = { index = i, bpm = bpm, num = num, den = den, offset = timepos - start_time }
        best_dist = dist
      end
    end
  end
  return best
end

-- Tempo/time-signature markers inside the region, except the one already used
-- for the tick-0 event (skip_index). Markers just after the start that were not
-- chosen as the start marker are kept, so no tempo change is ever dropped.
local function collect_tempo_changes(start_time, end_time, start_qn, events, skip_index)
  local count = reaper.CountTempoTimeSigMarkers(proj)
  local last_bpm = nil
  for i = 0, count - 1 do
    local ok, timepos, _, _, bpm, num, den = reaper.GetTempoTimeSigMarker(proj, i)

    if ok and i ~= skip_index
       and timepos >= start_time - 1e-9 and timepos < end_time - 1e-9 then
      local tick = tick_at_time(timepos, start_qn)
      events[#events + 1] = { tick = tick, order = 2, data = tempo_event(bpm) }
      last_bpm = bpm

      if num and num > 0 and den and den > 0 then
        events[#events + 1] = { tick = tick, order = 3, data = timesig_event(num, den) }
      end
    end
  end
  return last_bpm -- tempo of the last change inside the region, or nil
end

local function get_regions()
  local regions = {}
  local idx = 0
  while true do
    local retval, is_region, pos, region_end, name, id =
      reaper.EnumProjectMarkers3(proj, idx)
    if retval == 0 then break end

    if is_region then
      regions[#regions + 1] = {
        start_time = pos,
        end_time = region_end,
        name = (name ~= "" and name or ("Region " .. tostring(id))),
        id = id
      }
    end
    idx = idx + 1
  end
  table.sort(regions, function(a, b)
    if a.start_time ~= b.start_time then return a.start_time < b.start_time end
    return a.end_time < b.end_time
  end)
  return regions
end

local function main()
  local base_dir = prompt_value(
    "Export region MIDI files",
    "Base output directory:",
    DEFAULT_BASE_DIR
  )
  if not base_dir then return end

  local tempo_map_name = prompt_value(
    "Export region MIDI files",
    "MIDI filename (without .mid):",
    DEFAULT_TEMPO_MAP_NAME
  )
  if not tempo_map_name then return end

  base_dir = base_dir:gsub("[/\\]+$", "")
  tempo_map_name = sanitize_component(strip_mid_extension(tempo_map_name))
  local file_name = tempo_map_name .. ".mid" -- always lower-case extension

  if base_dir == "" then
    reaper.MB("The base output directory cannot be empty.", "Region MIDI export", 0)
    return
  end

  local regions = get_regions()
  if #regions == 0 then
    reaper.MB("No regions were found in the current project.", "Region MIDI export", 0)
    return
  end

  if not mkdir(base_dir) then
    reaper.MB("Could not create output directory:\n" .. base_dir, "Region MIDI export", 0)
    return
  end

  local success, failures = 0, {}
  reaper.PreventUIRefresh(1)

  for _, region in ipairs(regions) do
    local start_time, end_time = region.start_time, region.end_time
    local region_dir = join_path(base_dir, sanitize_component(region.name))
    local out_path = join_path(region_dir, file_name)

    if end_time <= start_time then
      failures[#failures + 1] = region.name .. ": invalid region length"
    elseif not mkdir(region_dir) then
      failures[#failures + 1] = region.name .. ": could not create directory"
    else
      local start_qn = reaper.TimeMap2_timeToQN(proj, start_time)
      local end_tick = tick_at_time(end_time, start_qn)

      -- Start tempo/time signature: an explicit marker near the region start
      -- wins; otherwise use the underlying values at the region start.
      local num, den, bpm = reaper.TimeMap_GetTimeSigAtTime(proj, start_time)
      local start_marker = find_start_marker(start_time)
      if start_marker then
        if start_marker.bpm and start_marker.bpm > 0 then bpm = start_marker.bpm end
        if start_marker.num and start_marker.num > 0
           and start_marker.den and start_marker.den > 0 then
          num, den = start_marker.num, start_marker.den
        end
      end

      local start_tick = (end_tick > START_TEMPO_TICK) and START_TEMPO_TICK or 0
      local events = {
        { tick = start_tick, order = 0, data = tempo_event(bpm) },
        { tick = start_tick, order = 1, data = timesig_event(num, den) }
      }

      local last_bpm = collect_tempo_changes(start_time, end_time, start_qn, events,
                                             start_marker and start_marker.index or nil)
      if ADD_END_TEMPO and end_tick > start_tick then
        events[#events + 1] = { tick = end_tick, order = 8,
                                data = tempo_event(last_bpm or bpm) }
      end
      if START_EVENT_TEXT ~= "" then
        events[#events + 1] = { tick = 0, order = 5,
          data = text_event((START_EVENT_TEXT:gsub("%%name", function() return region.name end))) }
      end
      if END_EVENT_TEXT ~= "" then
        events[#events + 1] = { tick = end_tick, order = 9,
          data = text_event((END_EVENT_TEXT:gsub("%%name", function() return region.name end))) }
      end

      if LOG_TO_CONSOLE then
        reaper.ShowConsoleMsg(string.format(
          "[%s] start %.3f BPM %d/%d (%s)\n", region.name, bpm, num, den,
          start_marker and string.format("tempo marker #%d, offset %+.4fs",
                                         start_marker.index, start_marker.offset)
                        or "no marker within threshold, underlying tempo"))
      end
      collect_markers(start_time, end_time, start_qn, events)

      local ok, err = write_midi(out_path, events, end_tick)
      if ok then
        success = success + 1
      else
        failures[#failures + 1] = region.name .. ": " .. tostring(err)
      end
    end
  end

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()

  local message = string.format(
    "Exported %d of %d regions.\n\nOutput directory:\n%s",
    success, #regions, base_dir
  )
  if #failures > 0 then
    message = message .. "\n\nFailures:\n- " .. table.concat(failures, "\n- ")
  end
  reaper.MB(message, "Region MIDI export", 0)
end

local ok, err = xpcall(main, debug.traceback)
if not ok then
  reaper.PreventUIRefresh(-1)
  reaper.MB("Region MIDI export failed:\n\n" .. tostring(err), "Region MIDI export", 0)
end
