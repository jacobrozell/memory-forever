--[[
Grouping with other players. Each player counts once per day.

Group member names are read out of combat only. If the roster changes during
combat, the update waits for PLAYER_REGEN_ENABLED, which avoids secret values
in restricted content.
]]
local _, ns = ...

local Safe = ns.Safe

local Group = { pending = false }
ns.Group = Group

function Group.fullName(unit)
  local name, realm = Safe.unitName(unit)
  if not name then return nil end
  realm = realm or Safe.str(Safe.api('GetRealmName')) or ''
  realm = string.gsub(realm, '%s', '')
  if realm == '' then return name end
  return name .. '-' .. realm
end

function Group.members()
  local units = {}
  if Safe.api('IsInRaid') then
    local count = tonumber(Safe.api('GetNumGroupMembers')) or 0
    for i = 1, count do table.insert(units, 'raid' .. i) end
  else
    local count = tonumber(Safe.api('GetNumSubgroupMembers')) or ((tonumber(Safe.api('GetNumGroupMembers')) or 1) - 1)
    for i = 1, count do table.insert(units, 'party' .. i) end
  end

  local names = {}
  for _, unit in ipairs(units) do
    local guid = Safe.unitGUID(unit)
    if guid and Safe.isPlayerGuid(guid) and Safe.api('UnitIsUnit', unit, 'player') ~= true then
      local fullName = Group.fullName(unit)
      if fullName then table.insert(names, fullName) end
    end
  end
  return names
end

--[[
The first Skyborne in a group, and the first of a class-and-race pair that
did not exist in original WoW. Said once per pair.
]]
function Group.noteFaces()
  if not ns.Forever or Safe.api('InCombatLockdown') then return end
  local units = {}
  if Safe.api('IsInRaid') then
    local count = tonumber(Safe.api('GetNumGroupMembers')) or 0
    for i = 1, count do table.insert(units, 'raid' .. i) end
  else
    local count = tonumber(Safe.api('GetNumSubgroupMembers')) or ((tonumber(Safe.api('GetNumGroupMembers')) or 1) - 1)
    for i = 1, count do table.insert(units, 'party' .. i) end
  end
  for _, unit in ipairs(units) do
    local guid = Safe.unitGUID(unit)
    if guid and Safe.isPlayerGuid(guid) and Safe.api('UnitIsUnit', unit, 'player') ~= true then
      local raceName, raceFile = ns.Safe.call(UnitRace, unit)
      local _, classFile = ns.Safe.call(UnitClass, unit)
      raceName = Safe.str(raceName)
      raceFile = Safe.str(raceFile) or raceName
      classFile = Safe.str(classFile)
      local skyborne = raceFile == 'Skyborne'
      if not skyborne and raceName then
        skyborne = string.find(string.lower(raceName), 'skyborne', 1, true) ~= nil
      end
      if skyborne then
        local previous = ns.record({
          category = 'misc', path = { 'people', 'Skyborne' }, interaction = 'meet', quiet = true,
          verbs = { past = 'grouped', pastConnector = 'with', present = 'group', presentConnector = 'with', subject = 'Skyborne' },
        })
        if previous.x < 1 then ns.Forever.say('This is the first Skyborne you have grouped with.') end
      elseif raceFile and classFile and ns.Forever.unusual[raceFile] and ns.Forever.unusual[raceFile][classFile] then
        local label = string.lower(raceName or raceFile) .. ' ' .. string.lower(classFile)
        local previous = ns.record({
          category = 'misc', path = { 'people', label }, interaction = 'meet', quiet = true,
          verbs = { past = 'grouped', pastConnector = 'with', present = 'group', presentConnector = 'with', subject = label },
        })
        if previous.x < 1 then ns.Forever.say('This is the first ' .. label .. ' you have grouped with.') end
      end
    end
  end
end

local function union(first, second)
  local names, seen = {}, {}
  for i = 1, 2 do
    local list = i == 1 and first or second
    if type(list) == 'table' then
      for _, name in ipairs(list) do
        if not seen[name] then
          seen[name] = true
          table.insert(names, name)
        end
      end
    end
  end
  return names
end

function Group.update()
  if not ns.Repository.isReady() then return end
  local current = Group.members()
  if Safe.api('InCombatLockdown') then
    Group.pending = true
    -- remember names that are readable now; someone may leave before combat ends
    if #current > 0 then Group.queued = union(Group.queued, current) end
    return
  end
  Group.pending = false
  local names = union(Group.queued, current)
  Group.queued = nil
  for _, fullName in ipairs(names) do
    local previous = ns.Repository.get('players', { fullName }, 'party')
    local groupedToday = previous.last and ns.Util.daysAgo(previous.last.date) == 0
    if not groupedToday then
      ns.record({
        category = 'players', path = { fullName }, interaction = 'party',
        verbs = { past = 'grouped', pastConnector = 'with', present = 'group', presentConnector = 'with', subject = fullName },
      })
    end
  end
  Group.noteFaces()
end

ns.Trackers.register('group', {
  label = 'Grouping with players',
  events = { 'GROUP_ROSTER_UPDATE' },
  apis = { 'GetNumGroupMembers' },
  setup = function(on)
    on('GROUP_ROSTER_UPDATE', Group.update)
    on('PLAYER_REGEN_ENABLED', function()
      if Group.pending then Group.update() end
    end)
    Group.update()
  end,
})
