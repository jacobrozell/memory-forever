--[[
Moments: user-set labels attached to every memory recorded while they're the
current moment ('/mem moment "Leveling with Sam"'). Memories store the moment
index. The labels live in MemoryForeverDB.moments, shared by the account so
old indexes keep their meaning. Which label is current is stored on the
character (currentMoment), so each character can be in a different moment.
]]
local _, ns = ...

local Moments = {}
ns.Moments = Moments

local function list()
  if ns.db and type(ns.db.moments) == 'table' then return ns.db.moments end
  return {}
end

local function character()
  if ns.Repository and ns.Repository.char then return ns.Repository.char() end
end

function Moments.add(label)
  label = ns.Util.trim(label)
  if label == '' or not ns.db then return nil end
  table.insert(ns.db.moments, label)
  local index = #ns.db.moments
  local char = character()
  if char then char.currentMoment = index end
  return index
end

function Moments.clear()
  local char = character()
  if char then char.currentMoment = nil end
end

function Moments.currentIndex()
  local char = character()
  local index = char and tonumber(char.currentMoment)
  if index and list()[index] then return index end
  return 0
end

function Moments.current()
  local index = Moments.currentIndex()
  if index < 1 then return nil end
  return list()[index]
end

function Moments.get(index)
  index = tonumber(index)
  if not index then return nil end
  return list()[index]
end

function Moments.all()
  return list()
end
