--[[
One memory per dungeon or raid run, written when you leave the instance.
The recap is how long it took, how many times you died, and who was with
you. Boss kills are not counted.
]]
local _, ns = ...

local Runs = { active = nil }
ns.Runs = Runs

local function shortName(name)
  return string.match(name, '^([^%-]+)') or name
end

local function remember(name)
  if not Runs.active or not name then return end
  for _, have in ipairs(Runs.active.party) do
    if have == name then return end
  end
  table.insert(Runs.active.party, name)
end

function Runs.capture()
  if not Runs.active or ns.Safe.api('InCombatLockdown') then return end
  local members = ns.Group.members and ns.Group.members() or {}
  for _, name in ipairs(members) do remember(shortName(name)) end
end

function Runs.noteDeath()
  if Runs.active then Runs.active.deaths = Runs.active.deaths + 1 end
end

function Runs.finish()
  local run = Runs.active
  Runs.active = nil
  if not run or not run.name then return end
  local seconds = math.floor(ns.Events.now() - (run.at or ns.Events.now()))
  if seconds < 10 and run.deaths == 0 then return end
  local previous = ns.record({
    category = 'zones', path = { run.name }, interaction = 'run', quiet = true,
    verbs = { past = 'ran', present = 'run', subject = run.name },
  })
  local first = previous and previous.x < 1 and ns.Forever and ns.Forever.instanceSentence(run.name)
  local function names(list)
    if #list == 1 then return list[1] end
    if #list == 2 then return list[1] .. ' and ' .. list[2] end
    return table.concat(list, ', ', 1, #list - 1) .. ', and ' .. list[#list]
  end
  local deaths = 'You did not die.'
  if run.deaths == 1 then deaths = 'You died once.'
  elseif run.deaths > 1 then deaths = 'You died ' .. run.deaths .. ' times.' end
  local company = #run.party == 0 and 'You were alone.' or ('You were with ' .. names(run.party) .. '.')
  local text = (first and (first .. ' ') or '')
    .. 'You left ' .. run.name .. ' after ' .. ns.Util.formatDuration(seconds) .. '. ' .. deaths .. ' ' .. company
  ns.print(text)
  if ns.Settings.get('placeToasts') then ns.Toast.show(run.name, text) end
end

function Runs.sync()
  local inside = ns.Safe.api('IsInInstance')
  if inside then
    if not Runs.active then
      Runs.active = { name = ns.Zones.location(), at = ns.Events.now(), deaths = 0, party = {} }
    end
    Runs.capture()
  elseif Runs.active then
    Runs.finish()
  end
end
