local H, WoW = ...
local describe, it = H.describe, H.it

local DUGHAN = { guid = 'Creature-0-1-2-3-240-0001', name = 'Marshal Dughan' }

describe('Return line', function()
  it('adds time, quests and the first-visit level', function()
    local ctl = WoW.start()
    local shown = {}
    ctl.ns.Toast.show = function(_, text) table.insert(shown, text) end
    ctl.units.npc = DUGHAN
    ctl.event('QUEST_COMPLETE')
    ctl.event('QUEST_TURNED_IN', 123, 100, 0)
    ctl.advance(125)
    ctl.moveTo('Westfall', '')
    ctl.advance(301)
    ctl.moveTo('Elwynn Forest', 'Goldshire')
    H.eq(#shown, 1)
    H.contains(shown[1], "You've been here 2 times")
    H.contains(shown[1], 'Your first visit was at level 10.')
    H.contains(shown[1], 'You have spent 2 minutes here.')
    H.contains(shown[1], 'You have turned in 1 quest here.')
  end)
end)

describe('Deathless streak', function()
  it('says how long it had been after five minutes', function()
    local ctl = WoW.start()
    ctl.advance(400)
    ctl.event('PLAYER_DEAD')
    H.contains(ctl.chatText(), 'You went 6 minutes without dying.')
    ctl.event('PLAYER_ALIVE')
    ctl.advance(20)
    ctl.event('PLAYER_DEAD')
    local _, n = ctl.chatText():gsub('without dying', '')
    H.eq(n, 1)
  end)

  it('stays quiet when the stretch is short', function()
    local ctl = WoW.start()
    ctl.advance(20)
    ctl.event('PLAYER_DEAD')
    H.falsy(string.find(ctl.chatText(), 'without dying', 1, true))
  end)
end)

describe('Dungeon runs', function()
  it('records one run when you leave', function()
    local ctl = WoW.start()
    ctl.inInstance = true
    ctl.groupSize = 2
    ctl.units.party1 = { guid = 'Player-1-00000002', name = 'Sam', realm = 'Forever Realm' }
    ctl.moveTo('The Deadmines', '')
    ctl.advance(45)
    ctl.event('PLAYER_DEAD')
    ctl.event('PLAYER_ALIVE')
    ctl.inInstance = false
    ctl.moveTo('Westfall', 'Moonbrook')
    local run = ctl.char().zones['The Deadmines'].run
    H.eq(run.x, 1)
    H.contains(ctl.chatText(), 'You left The Deadmines after 45 seconds. You died once. You were with Sam.')
  end)

  it('ignores a run you leave immediately', function()
    local ctl = WoW.start()
    ctl.inInstance = true
    ctl.moveTo('The Deadmines', '')
    ctl.inInstance = false
    ctl.moveTo('Westfall', 'Moonbrook')
    H.eq(ctl.char().zones['The Deadmines'].run, nil)
  end)
end)

describe('First equip', function()
  it('skips the gear you logged in wearing', function()
    local ctl = WoW.start({ configure = function(c)
      c.gear[16] = { name = 'Worn Axe', id = 25 }
    end })
    H.falsy(ctl.char().items and ctl.char().items['Worn Axe'])
    ctl.gear[16] = { name = 'Ancestral Sword', id = 1 }
    ctl.event('PLAYER_EQUIPMENT_CHANGED', 16)
    H.eq(ctl.char().items['Ancestral Sword'].equip.x, 1)
    H.contains(ctl.chatText(), 'This is the first time you have equipped Ancestral Sword.')
    ctl.event('PLAYER_EQUIPMENT_CHANGED', 16)
    H.eq(ctl.char().items['Ancestral Sword'].equip.x, 1)
    ctl.gear[16] = { name = 'Worn Axe', id = 25 }
    ctl.event('PLAYER_EQUIPMENT_CHANGED', 16)
    H.falsy(ctl.char().items['Worn Axe'])
  end)
end)

describe('Campfires', function()
  it('counts a camp when the buff comes up, once per lighting', function()
    local ctl = WoW.start()
    ctl.buffs[1] = { name = 'Camping', id = 1 }
    ctl.event('UNIT_AURA', 'player')
    ctl.event('UNIT_AURA', 'player')
    local camp = ctl.char().zones['Elwynn Forest'].subzones['Goldshire'].camp
    H.eq(camp.x, 1)
    H.contains(ctl.chatText(), 'This is your first campfire at Goldshire.')
    ctl.buffs[1] = nil
    ctl.event('UNIT_AURA', 'player')
    ctl.buffs[1] = { name = 'Camping', id = 1 }
    ctl.event('UNIT_AURA', 'player')
    H.eq(camp.x, 2)
    local _, n = ctl.chatText():gsub('first campfire', '')
    H.eq(n, 1)
  end)

  it('remembers a camp feature and who sat with you', function()
    local ctl = WoW.start()
    ctl.groupSize = 2
    ctl.units.party1 = { guid = 'Player-1-00000002', name = 'Sam', realm = 'Forever Realm' }
    ctl.buffs[1] = { name = 'Camping', id = 1 }
    ctl.buffs[2] = { name = 'Arcane Intellect', id = 2 }
    ctl.event('UNIT_AURA', 'player')
    ctl.buffs[3] = { name = 'Sharpening Wheel', id = 3 }
    ctl.event('UNIT_AURA', 'player')
    ctl.event('UNIT_AURA', 'player')
    local items = ctl.char().items
    H.eq(items['Sharpening Wheel'].feature.x, 1)
    H.falsy(items['Arcane Intellect'])
    H.falsy(items['Camping'])
    H.eq(ctl.char().players['Sam'].campfire.x, 1)
    H.contains(ctl.chatText(), 'This is the first time you have sat by a Sharpening Wheel.')
    H.contains(ctl.chatText(), 'This is the first time you have camped with Sam.')
    ctl.slash('buffs')
    H.contains(ctl.chatText(), 'Sharpening Wheel')
  end)
end)
