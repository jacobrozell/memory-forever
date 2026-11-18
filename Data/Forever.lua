--[[
Forever-only moments. The names are the ones Blizzard published for the
launch zones, dungeons, and raids. A sentence is said once, the first time
this character reaches that place or instance.
]]
local _, ns = ...

local Forever = {}
ns.Forever = Forever

Forever.zones = {
  ['Zephras Isle'] = 'This is your first time on Zephras Isle, where the Skyborne begin.',
  ['Riverglades'] = 'This is your first time in the Riverglades.',
  ['The Riverglades'] = 'This is your first time in the Riverglades.',
  ["Shen'Dralas"] = "This is your first time in Shen'Dralas.",
  ['Mount Hyjal'] = 'This is your first time on Mount Hyjal.',
  ['Hyjal'] = 'This is your first time on Mount Hyjal.',
}

Forever.instances = {
  ['Hall of Thanes'] = 'This is your first time in Hall of Thanes, a new Forever dungeon.',
  ['Ruins of Lordaeron'] = 'This is your first time in the Ruins of Lordaeron, a new Forever dungeon.',
  ['Excavation Site'] = 'This is your first time in the Excavation Site, a new Forever dungeon.',
  ['City of Dalaran'] = 'This is your first time in the City of Dalaran, a new Forever dungeon.',
  ['The Drowned City'] = 'This is your first time in the Drowned City, a new Forever dungeon.',
  ["Krol'dok Stronghold"] = "This is your first time in Krol'dok Stronghold, a new Forever dungeon.",
  ['Alcaz Prison'] = 'This is your first time in Alcaz Prison, a new Forever dungeon.',
  ['Alcaz Island Prison'] = 'This is your first time in Alcaz Prison, a new Forever dungeon.',
  ['Blackmaw Hold'] = 'This is your first time in Blackmaw Hold, a new Forever dungeon.',
  ["Shaper's Terrace"] = "This is your first time in Shaper's Terrace, a new Forever dungeon.",
  ['Barrow Deeps'] = 'This is your first time in the Barrow Deeps, a new Forever raid.',
  ['Hyjal Summit'] = 'This is your first time in Hyjal Summit, a new Forever raid.',
  ["Onyxia's Lair"] = "This is your first time in Onyxia's Lair.",
}

Forever.levels = {
  [25] = 'You reached level 25. This is when the Legacy System opens for most characters.',
  [45] = 'You reached level 45, a Legacy milestone for this class.',
  [60] = 'You reached level 60, a Legacy milestone for this class.',
}

-- Non-gathering primary professions. Their 150, 225, and 300 skill marks
-- are Legacy challenges. Gathering and secondary skills are not.
Forever.crafting = {
  Alchemy = true, Blacksmithing = true, Enchanting = true,
  Engineering = true, Leatherworking = true, Tailoring = true,
}

Forever.professionMarks = { 150, 225, 300 }

-- Race and class pairs that did not exist in original WoW. Race file tokens
-- are the second return of UnitRace. Undead is Scourge.
Forever.unusual = {
  Human = { HUNTER = true },
  Dwarf = { SHAMAN = true },
  Gnome = { PRIEST = true },
  Orc = { MAGE = true },
  Troll = { WARLOCK = true },
  Scourge = { PALADIN = true },
  Undead = { PALADIN = true },
}

function Forever.say(text)
  if not text or text == '' then return end
  ns.print(text)
  if ns.Settings.get('placeToasts') then ns.Toast.show(ns.NAME, text) end
end

function Forever.zoneSentence(name)
  return Forever.zones[name]
end

function Forever.instanceSentence(name)
  return Forever.instances[name]
end
