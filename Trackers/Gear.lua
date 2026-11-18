--[[
The first time you equip an item. The gear you are already wearing when the
addon starts is a baseline and is not recorded, so the first-equip date is
not the day you installed the addon.
]]
local _, ns = ...

local SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }

local Gear = { worn = {}, known = {}, seeded = false }
ns.Gear = Gear

local function itemAt(slot)
  local link = ns.Safe.str(ns.Safe.call(GetInventoryItemLink, 'player', slot))
  if not link then return nil end
  return string.match(link, '%[(.-)%]')
end

function Gear.scan()
  if not ns.Repository.isReady() then return end
  for _, slot in ipairs(SLOTS) do
    local name = itemAt(slot)
    if not Gear.seeded then
      if name then
        Gear.known[name] = true
        Gear.worn[slot] = name
      end
    else
      local previous = Gear.worn[slot]
      if name and name ~= previous and not Gear.known[name] then
        Gear.known[name] = true
        ns.record({
          category = 'items', path = { name }, interaction = 'equip', quiet = true,
          verbs = { past = 'equipped', present = 'equip', subject = name },
        })
        local text = 'This is the first time you have equipped ' .. name .. '.'
        ns.print(text)
        if ns.Settings.get('placeToasts') then ns.Toast.show(name, text) end
      end
      Gear.worn[slot] = name
    end
  end
  Gear.seeded = true
end

ns.Trackers.register('gear', {
  label = 'First time you equip an item',
  apis = { 'GetInventoryItemLink' },
  events = { 'PLAYER_EQUIPMENT_CHANGED' },
  setup = function(on)
    on('PLAYER_ENTERING_WORLD', function() Gear.scan() end)
    on('PLAYER_EQUIPMENT_CHANGED', function() Gear.scan() end)
    Gear.scan()
  end,
})
