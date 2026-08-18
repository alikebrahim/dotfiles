-- split-marker.lua (loaded via mmpv)
-- Press m to drop a split marker at the current position.
-- Markers are appended to <video>.markers (one float seconds per line).
-- u = undo last marker, p = list markers. Markers are flushed on every press,
-- so quitting (q) never loses them. The list resets on each file load.
local function marker_file()
  local path = mp.get_property("path")
  if not path or path:find("^%a+://") then return nil end -- local files only
  return path .. ".markers"
end

local function fmt(t)
  local h = math.floor(t / 3600)
  local m = math.floor((t % 3600) / 60)
  local s = t % 60
  if h > 0 then
    return string.format("%d:%02d:%05.2f", h, m, s)
  end
  return string.format("%d:%05.2f", m, s)
end

local function read_markers(f)
  local out, fh = {}, io.open(f, "r")
  if fh then
    for line in fh:lines() do
      local t = tonumber(line)
      if t then out[#out + 1] = t end
    end
    fh:close()
  end
  return out
end

local function write_markers(f, list)
  local fh = io.open(f, "w")
  if not fh then return false end
  for _, t in ipairs(list) do
    fh:write(string.format("%.3f\n", t))
  end
  fh:close()
  return true
end

local function add_marker()
  local f = marker_file()
  if not f then
    mp.osd_message("split-marker: not a local file", 2)
    return
  end
  local t = mp.get_property_number("time-pos") or 0
  local list = read_markers(f)
  list[#list + 1] = t
  if write_markers(f, list) then
    mp.osd_message(string.format("Marker %d @ %s", #list, fmt(t)), 2)
  else
    mp.osd_message("split-marker: cannot write " .. f, 2)
  end
end

local function undo_marker()
  local f = marker_file()
  if not f then return end
  local list = read_markers(f)
  if #list == 0 then
    mp.osd_message("No markers to undo", 1.5)
    return
  end
  local removed = table.remove(list)
  write_markers(f, list)
  mp.osd_message(string.format("Removed @ %s (%d left)", fmt(removed), #list), 2)
end

local function show_markers()
  local f = marker_file()
  if not f then return end
  local list = read_markers(f)
  if #list == 0 then
    mp.osd_message("No markers yet - press m to add", 2)
    return
  end
  local lines = {}
  for i, t in ipairs(list) do
    lines[#lines + 1] = string.format("%2d. %s", i, fmt(t))
  end
  mp.osd_message("Markers:\n" .. table.concat(lines, "\n"), 3)
end

mp.add_key_binding("m", "split-marker-add", add_marker)
mp.add_key_binding("u", "split-marker-undo", undo_marker)
mp.add_key_binding("p", "split-marker-show", show_markers)

-- fresh marker list per session (truncates the sidecar on file load)
mp.register_event("file-loaded", function()
  local f = marker_file()
  if f then write_markers(f, {}) end
  mp.osd_message("split-marker ready (m=mark, u=undo, p=list)", 2)
end)
