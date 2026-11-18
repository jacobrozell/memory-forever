--[[
Campfires, detected from the "Camping" buff. Each time the buff comes up it
counts once for the place you are in. An aura that is already up is one camp,
not a new one on every aura update.
]]
local _, ns = ...

local Camps = { lit = false }
ns.Camps = Camps

-- Object names from the Forever camping recipes. A higher tier keeps the
-- lower tier's benefit, and the buff name in the client may match either,
-- so both are listed. /mem buffs prints whatever you actually have.
local FEATURES = {
  ['Mana Well'] = true, ['Fermenter'] = true, ['Alchemy Laboratory'] = true,
  ['Sharpening Wheel'] = true, ['Anvil'] = true, ['Master Forge'] = true,
  ['Enchanted Lute'] = true, ['Arcane Salvager'] = true, ['Arcane Forge'] = true,
  ['First Aid Kit'] = true, ['Toxin Study'] = true, ["Plague Doctor's Laboratory"] = true,
  ['Fish Bowl'] = true, ['Fishing Bowl'] = true, ['Fishing Rack'] = true, ['Fishing Hut'] = true,
  ['Incense Candle'] = true, ['Greenhouse'] = true, ['Seed Hybridizer'] = true,
  ['Camp Tent'] = true, ['Tanning Rack'] = true, ['Sewing Machine'] = true,
  ['Lodestone'] = true, ['Rock Garden'] = true, ['Molten Foundry'] = true,
  ['Camp Chair'] = true, ['Field Guide'] = true, ["Trapper's Workbench"] = true,
  ['Faction Banner'] = true, ['Alliance Banner'] = true, ['Horde Banner'] = true,
  ['Spinning Wheel'] = true, ['Loom'] = true,
}

local function buffName(index)
  if C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then
    local data = ns.Safe.call(C_UnitAuras.GetBuffDataByIndex, 'player', index)
    if type(data) ~= 'table' then return nil, true end
    return ns.Safe.str(data.name), false
  end
  if type(UnitAura) ~= 'function' then return nil, true end
  local name = ns.Safe.str(ns.Safe.call(UnitAura, 'player', index, 'HELPFUL'))
  if not name then return nil, true end
  return name, false
end

local function eachBuff()
  local names = {}
  for i = 1, 40 do
    local name, done = buffName(i)
    if done then break end
    if name then table.insert(names, name) end
  end
  return names
end

function Camps.listBuffs()
  return eachBuff()
end

local function camping()
  for _, name in ipairs(eachBuff()) do
    if name == 'Camping' then return true end
  end
  return false
end

local function article(name)
  if string.match(name, '^[AEIOUaeiou]') then return 'an ' end
  return 'a '
end

local function shortName(name)
  return string.match(name, '^([^%-]+)') or name
end

local function remember(spec, text)
  local previous = ns.record(spec)
  if previous.x < 1 then
    ns.print(text)
    if ns.Settings.get('placeToasts') then ns.Toast.show(spec.verbs.subject, text) end
  end
end

local function noteCompany()
  Camps.company = Camps.company or {}
  local members = ns.Group.members and ns.Group.members() or {}
  for _, name in ipairs(members) do
    local short = shortName(name)
    if not Camps.company[short] then
      Camps.company[short] = true
      remember({
        category = 'players', path = { short }, interaction = 'campfire', quiet = true,
        verbs = { past = 'camped', pastConnector = 'with', present = 'camp', presentConnector = 'with', subject = short },
      }, 'This is the first time you have camped with ' .. short .. '.')
    end
  end
end

local function noteFeatures()
  Camps.seen = Camps.seen or {}
  for _, name in ipairs(eachBuff()) do
    if FEATURES[name] and not Camps.seen[name] then
      Camps.seen[name] = true
      remember({
        category = 'items', path = { name }, interaction = 'feature', quiet = true,
        verbs = { past = 'sat by', present = 'sit by', subject = name },
      }, 'This is the first time you have sat by ' .. article(name) .. name .. '.')
    end
  end
end

function Camps.check()
  if not ns.Repository.isReady() then return end
  local has = camping()
  if not has then
    Camps.lit = false
    Camps.seen = nil
    Camps.company = nil
    return
  end
  if Camps.lit then
    noteCompany()
    noteFeatures()
    return
  end
  local zone, subZone = ns.Zones.location()
  if not zone then return end
  local place = (subZone and subZone ~= zone) and subZone or zone
  local path = (subZone and subZone ~= zone) and { zone, 'subzones', subZone } or { zone }
  local previous = ns.record({
    category = 'zones', path = path, interaction = 'camp', quiet = true,
    verbs = { past = 'camped', pastConnector = 'at', present = 'camp', presentConnector = 'at', subject = place },
  })
  Camps.lit = true
  Camps.seen = {}
  Camps.company = {}
  if previous.x < 1 then
    local text = 'This is your first campfire at ' .. place .. '.'
    ns.print(text)
    if ns.Settings.get('placeToasts') then ns.Toast.show(place, text) end
  end
  noteCompany()
  noteFeatures()
end

ns.Trackers.register('camps', {
  label = 'Campfires',
  events = { 'UNIT_AURA' },
  setup = function(on)
    on('UNIT_AURA', function(_, unit)
      local ok, other = pcall(function() return unit ~= nil and unit ~= 'player' end)
      if ok and other then return end
      Camps.check()
    end)
  end,
})
