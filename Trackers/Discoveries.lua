--[[
Areas the world announces the first time you find them.

The client sends UI_INFO_MESSAGE with its own ERR_ZONE_EXPLORED strings
("Discovered Northshire Abbey: 50 experience gained"). That is the exploration
event. Each area is stored once, under the zone you were in. Coming back to
the zone says how many you have found there.
]]
local _, ns = ...

local Safe = ns.Safe
local Util = ns.Util

local Discoveries = { cached = nil }
ns.Discoveries = Discoveries

function Discoveries.patterns()
  if Discoveries.cached then return Discoveries.cached end
  local list = {}
  if type(ERR_ZONE_EXPLORED_XP) == 'string' then
    table.insert(list, Util.formatToPattern(ERR_ZONE_EXPLORED_XP))
  end
  if type(ERR_ZONE_EXPLORED) == 'string' and ERR_ZONE_EXPLORED ~= ERR_ZONE_EXPLORED_XP then
    table.insert(list, Util.formatToPattern(ERR_ZONE_EXPLORED))
  end
  Discoveries.cached = list
  return list
end

--[[
Area name from a discovery message, or nil.
]]
function Discoveries.parse(message)
  message = Safe.str(message)
  if not message then return nil end
  for _, pattern in ipairs(Discoveries.patterns()) do
    local area = Safe.str(string.match(message, pattern))
    if area then return area end
  end
  return nil
end

function Discoveries.onInfo(_, _, message)
  local area = Discoveries.parse(message)
  if not area or not ns.Repository.isReady() then return end
  local zone = ns.Zones and select(1, ns.Zones.location())
  if not zone then return end
  local path = { zone, 'discoveries', area }
  if ns.Repository.get('zones', path, 'discover').x >= 1 then return end
  ns.record({ category = 'zones', path = path, interaction = 'discover', quiet = true })
  local where = area ~= zone and (' in ' .. zone) or ''
  ns.print('You discovered ' .. area .. where .. '.')
end

ns.Trackers.register('discoveries', {
  label = 'Area discoveries',
  events = { 'UI_INFO_MESSAGE' },
  setup = function(on)
    on('UI_INFO_MESSAGE', Discoveries.onInfo)
  end,
})
