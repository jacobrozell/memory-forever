local H, WoW = ...
local describe, it = H.describe, H.it

describe('Forever places', function()
  it('names a new zone the first time you enter it', function()
    local ctl = WoW.start()
    ctl.moveTo('The Riverglades', 'Stillwater')
    H.contains(ctl.chatText(), 'This is your first time in the Riverglades.')
    ctl.advance(400)
    ctl.moveTo('Elwynn Forest', 'Goldshire')
    ctl.advance(400)
    ctl.moveTo('The Riverglades', 'Stillwater')
    local _, n = ctl.chatText():gsub('first time in the Riverglades', '')
    H.eq(n, 1)
  end)

  it('names Shen\'Dralas and Mount Hyjal, and stays quiet in an old zone', function()
    local ctl = WoW.start()
    ctl.moveTo('Redridge Mountains', 'Lakeshire')
    H.notContains(ctl.chatText(), 'first time')
    ctl.advance(400)
    ctl.moveTo("Shen'Dralas", '')
    H.contains(ctl.chatText(), "This is your first time in Shen'Dralas.")
    ctl.advance(400)
    ctl.moveTo('Mount Hyjal', '')
    H.contains(ctl.chatText(), 'This is your first time on Mount Hyjal.')
  end)

  it('names a new dungeon on the first run', function()
    local ctl = WoW.start()
    ctl.inInstance = true
    ctl.moveTo('Hall of Thanes', '')
    ctl.advance(45)
    ctl.inInstance = false
    ctl.moveTo('Dun Morogh', 'Ironforge')
    H.contains(ctl.chatText(), 'This is your first time in Hall of Thanes, a new Forever dungeon.')
    ctl.inInstance = true
    ctl.advance(400)
    ctl.moveTo('Hall of Thanes', '')
    ctl.advance(45)
    ctl.inInstance = false
    ctl.moveTo('Dun Morogh', 'Ironforge')
    local _, n = ctl.chatText():gsub('new Forever dungeon', '')
    H.eq(n, 1)
  end)

  it('names a raid on the first run and ignores a walk back out', function()
    local ctl = WoW.start()
    ctl.inInstance = true
    ctl.moveTo('Barrow Deeps', '')
    ctl.inInstance = false
    ctl.moveTo('Mount Hyjal', '')
    H.notContains(ctl.chatText(), 'Barrow Deeps')
    ctl.inInstance = true
    ctl.advance(400)
    ctl.moveTo('Hyjal Summit', '')
    ctl.advance(45)
    ctl.inInstance = false
    ctl.moveTo('Mount Hyjal', '')
    H.contains(ctl.chatText(), 'This is your first time in Hyjal Summit, a new Forever raid.')
    H.contains(ctl.chatText(), 'You left Hyjal Summit after')
  end)

  it('uses the Alcaz Prison sentence for the island alias', function()
    local ctl = WoW.start()
    ctl.inInstance = true
    ctl.moveTo('Alcaz Island Prison', '')
    ctl.advance(45)
    ctl.inInstance = false
    ctl.moveTo('Dustwallow Marsh', '')
    H.contains(ctl.chatText(), 'This is your first time in Alcaz Prison, a new Forever dungeon.')
  end)
end)

describe('Legacy milestones', function()
  it('speaks at level 25, 45, and 60', function()
    local ctl = WoW.start()
    ctl.event('PLAYER_LEVEL_UP', 11)
    H.falsy(string.find(ctl.chatText(), 'Legacy', 1, true))
    ctl.event('PLAYER_LEVEL_UP', 25)
    H.contains(ctl.chatText(), 'You reached level 25. This is when the Legacy System opens for most characters.')
    ctl.event('PLAYER_LEVEL_UP', 45)
    H.contains(ctl.chatText(), 'You reached level 45, a Legacy milestone for this class.')
    ctl.event('PLAYER_LEVEL_UP', 60)
    H.contains(ctl.chatText(), 'You reached level 60, a Legacy milestone for this class.')
    local _, n = ctl.chatText():gsub('Legacy milestone', '')
    H.eq(n, 2)
  end)

  it('speaks when a crafting profession crosses 150, and ignores the skill you logged in with', function()
    local ctl = WoW.start({ configure = function(c)
      c.professions = { { name = 'Alchemy', rank = 140 } }
    end })
    H.falsy(string.find(ctl.chatText(), 'Alchemy reached', 1, true))
    ctl.professions[1].rank = 150
    ctl.event('SKILL_LINES_CHANGED')
    H.contains(ctl.chatText(), 'Alchemy reached 150. That is a Legacy milestone for a crafting profession.')
    ctl.professions[1].rank = 160
    ctl.event('SKILL_LINES_CHANGED')
    local _, n = ctl.chatText():gsub('Alchemy reached', '')
    H.eq(n, 1)
    ctl.professions[1] = { name = 'Mining', rank = 300 }
    ctl.event('SKILL_LINES_CHANGED')
    H.falsy(string.find(ctl.chatText(), 'Mining reached', 1, true))
  end)

  it('names every mark a crafting skill jumps across, and stays quiet when the skill falls', function()
    local ctl = WoW.start({ configure = function(c)
      c.professions = { { name = 'Enchanting', rank = 100 } }
    end })
    ctl.professions[1].rank = 300
    ctl.event('SKILL_LINES_CHANGED')
    H.contains(ctl.chatText(), 'Enchanting reached 150.')
    H.contains(ctl.chatText(), 'Enchanting reached 225.')
    H.contains(ctl.chatText(), 'Enchanting reached 300.')
    ctl.professions[1].rank = 200
    ctl.event('SKILL_LINES_CHANGED')
    local _, n = ctl.chatText():gsub('Enchanting reached', '')
    H.eq(n, 3)
  end)

  it('sees a profession that is not in the first slot', function()
    local ctl = WoW.start({ configure = function(c)
      c.professions = { [2] = { name = 'Tailoring', rank = 149 } }
    end })
    H.notContains(ctl.chatText(), 'Tailoring reached')
    ctl.professions[2].rank = 150
    ctl.event('SKILL_LINES_CHANGED')
    H.contains(ctl.chatText(), 'Tailoring reached 150. That is a Legacy milestone for a crafting profession.')
  end)

  it('reads the skill book when the profession list is missing, and skips headers', function()
    local ctl = WoW.start({ configure = function(c)
      c.professions = { { name = 'Blacksmithing', rank = 200 } }
    end })
    ctl.env.GetProfessions = nil
    ctl.env.GetProfessionInfo = nil
    ctl.env.GetNumSkillLines = function() return 2 end
    ctl.env.GetSkillLineInfo = function(index)
      if index == 1 then return 'Professions', true, false, 0 end
      return 'Blacksmithing', false, false, 300
    end
    ctl.event('CHAT_MSG_SKILL', '')
    H.contains(ctl.chatText(), 'Blacksmithing reached 225.')
    H.contains(ctl.chatText(), 'Blacksmithing reached 300.')
    H.notContains(ctl.chatText(), 'Blacksmithing reached 150.')
    H.notContains(ctl.chatText(), 'Professions reached')
  end)
end)

describe('Exploration', function()
  it('remembers each discovered area once and counts them on the way back', function()
    local ctl = WoW.start()
    local shown = {}
    ctl.ns.Toast.show = function(_, text) table.insert(shown, text) end
    ctl.event('UI_INFO_MESSAGE', 0, 'Discovered Northshire Abbey: 50 experience gained')
    H.contains(ctl.chatText(), 'You discovered Northshire Abbey in Elwynn Forest.')
    ctl.event('UI_INFO_MESSAGE', 0, 'Discovered Northshire Abbey: 50 experience gained')
    ctl.event('UI_INFO_MESSAGE', 0, 'You are not in a party.')
    ctl.event('UI_INFO_MESSAGE', 0, ctl.SECRET)
    local _, n = ctl.chatText():gsub('You discovered', '')
    H.eq(n, 1)
    H.eq(#ctl.errors, 0)
    ctl.event('UI_INFO_MESSAGE', 0, 'Discovered: Northshire Vineyards')
    H.contains(ctl.chatText(), 'You discovered Northshire Vineyards in Elwynn Forest.')
    ctl.advance(400)
    ctl.moveTo('Westfall', 'Sentinel Hill')
    ctl.advance(400)
    ctl.moveTo('Elwynn Forest', 'Goldshire')
    H.eq(#shown, 1)
    H.contains(shown[1], 'You have discovered 2 areas in Elwynn Forest.')
    local lines = ctl.ns.Queries.statsLines()
    local found = false
    for _, line in ipairs(lines) do
      if string.find(line, 'Areas discovered', 1, true) and string.find(line, '2', 1, true) then found = true end
    end
    H.truthy(found)
  end)

  it('lists the area in the journal and does not borrow another zone\'s count', function()
    local ctl = WoW.start()
    ctl.event('UI_INFO_MESSAGE', 0, 'Discovered: Elwynn Forest')
    H.contains(ctl.chatText(), 'You discovered Elwynn Forest.')
    H.notContains(ctl.chatText(), 'in Elwynn Forest')
    local stats = ctl.ns.Queries.stats()
    H.eq(stats.areas, 1)
    H.eq(stats.zones, 1)
    local listed = false
    for _, entry in ipairs(ctl.ns.Queries.entries('zones')) do
      if entry.label == 'Elwynn Forest, Elwynn Forest' then
        listed = true
        H.contains(ctl.ns.Queries.formatEntry(entry), 'discovered 1 time')
      end
    end
    H.truthy(listed)
    local lines = ctl.ns.Queries.here('Elwynn Forest', 'Goldshire')
    H.contains(lines, 'discovered')
    H.contains(lines, 'Elwynn Forest')
    ctl.advance(400)
    ctl.moveTo('Westfall', 'Sentinel Hill')
    ctl.event('UI_INFO_MESSAGE', 0, 'Discovered: The Jansen Stead')
    ctl.advance(400)
    ctl.moveTo('Elwynn Forest', 'Goldshire')
    H.eq(ctl.ns.Repository.areasDiscovered('Elwynn Forest'), 1)
    H.eq(ctl.ns.Repository.areasDiscovered('Westfall'), 1)
  end)
end)

describe('New people', function()
  it('remembers the first Skyborne and the first new class pair', function()
    local ctl = WoW.start()
    ctl.groupSize = 2
    ctl.units.party1 = { guid = 'Player-1-00000002', name = 'Sera', race = 'Skyborne', raceFile = 'Skyborne', class = 'HUNTER' }
    ctl.event('GROUP_ROSTER_UPDATE')
    ctl.event('GROUP_ROSTER_UPDATE')
    H.contains(ctl.chatText(), 'This is the first Skyborne you have grouped with.')
    local _, n = ctl.chatText():gsub('first Skyborne', '')
    H.eq(n, 1)

    ctl.groupSize = 3
    ctl.units.party2 = { guid = 'Player-1-00000003', name = 'Grosh', race = 'Orc', raceFile = 'Orc', class = 'MAGE' }
    ctl.event('GROUP_ROSTER_UPDATE')
    H.contains(ctl.chatText(), 'This is the first orc mage you have grouped with.')
  end)

  it('stays quiet for an old class pair and speaks for an undead paladin', function()
    local ctl = WoW.start()
    ctl.groupSize = 2
    ctl.units.party1 = { guid = 'Player-1-00000002', name = 'Sam', race = 'Human', raceFile = 'Human', class = 'WARRIOR' }
    ctl.event('GROUP_ROSTER_UPDATE')
    H.notContains(ctl.chatText(), 'first')
    ctl.groupSize = 3
    ctl.units.party2 = { guid = 'Player-1-00000003', name = 'Mira', race = 'Undead', raceFile = 'Scourge', class = 'PALADIN' }
    ctl.event('GROUP_ROSTER_UPDATE')
    H.contains(ctl.chatText(), 'This is the first undead paladin you have grouped with.')
  end)

  it('recognizes a Skyborne whose race file is not the English token', function()
    local ctl = WoW.start()
    ctl.groupSize = 2
    ctl.units.party1 = { guid = 'Player-1-00000002', name = 'Sera', race = 'Skyborne Wayfarer', raceFile = 'ShenDorei', class = 'HUNTER' }
    ctl.event('GROUP_ROSTER_UPDATE')
    H.contains(ctl.chatText(), 'This is the first Skyborne you have grouped with.')
    H.notContains(ctl.chatText(), 'human hunter')
  end)

  it('waits until combat ends before naming someone new', function()
    local ctl = WoW.start()
    ctl.inCombat = true
    ctl.groupSize = 2
    ctl.units.party1 = { guid = 'Player-1-00000002', name = 'Grosh', race = 'Orc', raceFile = 'Orc', class = 'MAGE' }
    ctl.event('GROUP_ROSTER_UPDATE')
    H.notContains(ctl.chatText(), 'orc mage')
    ctl.inCombat = false
    ctl.event('PLAYER_REGEN_ENABLED')
    H.contains(ctl.chatText(), 'This is the first orc mage you have grouped with.')
  end)
end)
