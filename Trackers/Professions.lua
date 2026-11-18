--[[
Legacy milestones for crafting professions: skill 150, 225, and 300.
The skill you already have at login is a baseline and is not announced.
]]
local _, ns = ...

local Professions = { ranks = {}, seeded = false }
ns.Professions = Professions

local function note(name, rank)
  name = ns.Safe.str(name)
  rank = tonumber(rank)
  if not name or not rank or not ns.Forever.crafting[name] then return end
  local previous = Professions.ranks[name]
  Professions.ranks[name] = rank
  if not Professions.seeded or not previous or rank <= previous then return end
  for _, mark in ipairs(ns.Forever.professionMarks) do
    if previous < mark and rank >= mark then
      ns.Forever.say(name .. ' reached ' .. mark .. '. That is a Legacy milestone for a crafting profession.')
    end
  end
end

function Professions.scan()
  if not ns.Repository.isReady() or not ns.Forever then return end
  if type(GetProfessions) == 'function' and type(GetProfessionInfo) == 'function' then
    local i1, i2, i3, i4 = ns.Safe.call(GetProfessions)
    local slots = { i1, i2, i3, i4 }
    for i = 1, 4 do
      local index = slots[i]
      if index then
        local name, _, rank = ns.Safe.call(GetProfessionInfo, index)
        note(name, rank)
      end
    end
  elseif type(GetNumSkillLines) == 'function' and type(GetSkillLineInfo) == 'function' then
    local count = tonumber(ns.Safe.call(GetNumSkillLines)) or 0
    for i = 1, count do
      local name, header, _, rank = ns.Safe.call(GetSkillLineInfo, i)
      if not header then note(name, rank) end
    end
  end
  Professions.seeded = true
end

ns.Trackers.register('professions', {
  label = 'Profession Legacy milestones',
  setup = function(on)
    on('SKILL_LINES_CHANGED', Professions.scan)
    on('CHAT_MSG_SKILL', Professions.scan)
    Professions.scan()
  end,
})
