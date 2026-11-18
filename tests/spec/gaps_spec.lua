local H, WoW = ...
local describe, it = H.describe, H.it

local DUGHAN = { guid = 'Creature-0-1-2-3-240-0001', name = 'Marshal Dughan' }

describe('Command edges', function()
  it('keeps an unclosed quote as the rest of the line', function()
    local ctl = WoW.start({ login = false })
    local tokens = ctl.ns.Commands.tokenize('moment "Hello there')
    H.eq(tokens[1], 'moment')
    H.eq(tokens[2], 'Hello there')
  end)

  it('refuses commands before the database exists', function()
    local ctl = WoW.start({ login = false })
    ctl.slash('stats')
    H.contains(ctl.chatText(), 'Still loading')
  end)

  it('explains a missing moment, a bad get, a bad set, and an empty buff list', function()
    local ctl = WoW.start()
    ctl.slash('moment')
    H.contains(ctl.chatText(), 'No moment on this character')
    ctl.slash('addm')
    H.contains(ctl.chatText(), 'Please provide a moment')
    ctl.slash('get')
    H.contains(ctl.chatText(), 'Usage: /mem get')
    ctl.slash('get nope')
    H.contains(ctl.chatText(), 'No setting called nope')
    ctl.slash('set printChance')
    H.contains(ctl.chatText(), 'Usage: /mem set')
    ctl.slash('buffs')
    H.contains(ctl.chatText(), 'No buffs found')
  end)

  it('says when the zone is unknown and trims a long place timeline', function()
    local ctl = WoW.start()
    ctl.env.GetZoneText = function() return nil end
    ctl.env.GetSubZoneText = function() return nil end
    ctl.slash('here')
    H.contains(ctl.chatText(), "I don't know where we are yet.")

    local placed = WoW.start()
    for i = 1, 14 do
      placed.ns.Repository.store('npcs', { 'Person ' .. i }, 'talk', 1)
    end
    placed.slash('here')
    H.contains(placed.chatText(), 'more in /mem journal')
  end)

  it('prints debug lines after a memory once debug is on', function()
    local ctl = WoW.start()
    ctl.slash('debug on')
    ctl.units.npc = DUGHAN
    ctl.event('GOSSIP_SHOW')
    H.contains(ctl.chatText(), '[debug]')
  end)
end)

describe('Runs and camps the suite had not worded', function()
  it('names two companions, three companions, and more than one death', function()
    local ctl = WoW.start()
    ctl.inInstance = true
    ctl.groupSize = 3
    ctl.units.party1 = { guid = 'Player-1-00000002', name = 'Sam', realm = 'Forever Realm' }
    ctl.units.party2 = { guid = 'Player-1-00000003', name = 'Alex', realm = 'Forever Realm' }
    ctl.moveTo('The Stockade', '')
    ctl.event('ZONE_CHANGED')
    ctl.advance(20)
    ctl.inInstance = false
    ctl.moveTo('Stormwind City', '')
    H.contains(ctl.chatText(), 'You were with Sam and Alex.')
    H.contains(ctl.chatText(), 'You did not die.')

    ctl.inInstance = true
    ctl.groupSize = 4
    ctl.units.party3 = { guid = 'Player-1-00000004', name = 'Jo', realm = 'Forever Realm' }
    ctl.advance(400)
    ctl.moveTo('Razorfen Downs', '')
    ctl.advance(15)
    ctl.event('PLAYER_DEAD')
    ctl.event('PLAYER_ALIVE')
    ctl.advance(5)
    ctl.event('PLAYER_DEAD')
    ctl.inInstance = false
    ctl.advance(400)
    ctl.moveTo('The Barrens', '')
    H.contains(ctl.chatText(), 'You were with Sam, Alex, and Jo.')
    H.contains(ctl.chatText(), 'You died 2 times.')
  end)

  it('uses an for a vowel feature, ignores other units, and reads the modern aura API', function()
    local ctl = WoW.start()
    ctl.moveTo('Westfall', '')
    ctl.event('UNIT_AURA', 'party1')
    H.notContains(ctl.chatText(), 'campfire')
    ctl.env.C_UnitAuras = {
      GetBuffDataByIndex = function(_, index)
        if index == 1 then return { name = 'Camping' } end
        if index == 2 then return { name = 'Anvil' } end
        return nil
      end,
    }
    ctl.event('UNIT_AURA', 'player')
    H.contains(ctl.chatText(), 'This is your first campfire at Westfall.')
    H.contains(ctl.chatText(), 'This is the first time you have sat by an Anvil.')
  end)
end)

describe('Gear, loot, and reminders that were easy to miss', function()
  it('does not record an empty slot', function()
    local ctl = WoW.start()
    ctl.gear[16] = nil
    ctl.event('PLAYER_EQUIPMENT_CHANGED', 16)
    H.falsy(next(ctl.char().items))
    H.noErrors(ctl)
  end)

  it('reads an item name from GetItemInfo when the loot text has no brackets', function()
    local ctl = WoW.start()
    ctl.env.C_Item.GetItemInfo = function() return 'Plain Cloth' end
    ctl.event('CHAT_MSG_LOOT', 'You receive loot: item:2589.')
    H.eq(ctl.char().items['Plain Cloth'].loot.x, 1)
  end)

  it('screenshots when the chance says so, and skips the call when Screenshot is missing', function()
    local ctl = WoW.start()
    ctl.ns.Settings.set('printChance', 0)
    ctl.ns.Settings.set('screenshotChance', 1)
    ctl.units.npc = DUGHAN
    ctl.event('GOSSIP_SHOW')
    ctl.runTimers()
    H.eq(ctl.screenshots, 1)
    H.eq(#ctl.raidNotices, 1)
    ctl.env.Screenshot = nil
    H.eq(ctl.ns.Reminders.screenshot('caption'), false)
    ctl.ns.Reminders.resetPlaceThrottle()
  end)
end)

describe('People in a raid', function()
  it('reads raid units, not party units', function()
    local ctl = WoW.start()
    ctl.raid = true
    ctl.groupSize = 2
    ctl.units.raid1 = { guid = 'Player-1-00000001', name = 'Tester', race = 'Human', raceFile = 'Human', class = 'WARRIOR' }
    ctl.units.raid2 = { guid = 'Player-1-00000002', name = 'Mira', race = 'Undead', raceFile = 'Scourge', class = 'PALADIN' }
    ctl.event('GROUP_ROSTER_UPDATE')
    H.contains(ctl.chatText(), 'This is the first undead paladin you have grouped with.')
    H.truthy(ctl.char().players['Mira-ForeverRealm'])
  end)
end)

describe('Journal, options, minimap, and tooltips', function()
  it('searches, cycles sort, and caps a long list', function()
    local ctl = WoW.start()
    ctl.ns.Journal.open()
    local box = ctl.env.MemoryForeverJournalSearch
    box:SetText('Goldshire')
    box._scripts.OnTextChanged(box)
    H.eq(ctl.ns.Journal.search, 'Goldshire')
    box._scripts.OnEscapePressed(box)
    for _, frame in ipairs(ctl.frames) do
      if frame._width == 110 and frame._scripts.OnClick then frame:Click() end
    end
    H.eq(ctl.ns.Journal.sort, 'recent')
    ctl.ns.Queries.MAX_ROWS = 1
    ctl.advanceDays(2)
    ctl.moveTo('Westfall', 'Sentinel Hill')
    local lines = ctl.ns.Queries.lines('zones', '', 'recent')
    H.contains(lines[1], 'Sentinel Hill')
    H.contains(lines, 'more')
  end)

  it('says the journal is not ready, and survives a frame that will not build', function()
    local quiet = WoW.start({ login = false })
    H.eq(quiet.ns.Journal.open(), false)
    H.contains(quiet.chatText(), 'Memories are still loading.')

    local ctl = WoW.start()
    local create = ctl.env.CreateFrame
    ctl.env.CreateFrame = function() error('frame broke') end
    H.eq(ctl.ns.Journal.open(), false)
    H.contains(ctl.chatText(), 'could not be created')
    ctl.env.CreateFrame = create
  end)

  it('falls back to the old options panel and says when that is missing too', function()
    local ctl = WoW.start({ configure = function(c)
      c.env.Settings.RegisterCanvasLayoutCategory = nil
      c.env.InterfaceOptions_AddCategory = function(panel) c.legacyPanel = panel end
      c.env.InterfaceOptionsFrame_OpenToCategory = function(panel) c.legacyOpened = panel end
    end })
    ctl.slash('config')
    H.truthy(ctl.legacyOpened)
    ctl.env.InterfaceOptionsFrame_OpenToCategory = nil
    ctl.ns.Options.open()
    H.contains(ctl.chatText(), 'Open Options > AddOns')
  end)

  it('reports a broken options panel and a broken minimap button', function()
    local ctl = WoW.start({ configure = function(c)
      c.env.Settings.RegisterCanvasLayoutCategory = function() error('options broke') end
      local create = c.env.CreateFrame
      c.env.CreateFrame = function(kind, name, parent, template)
        if name == 'MemoryForeverMinimapButton' then error('minimap broke') end
        return create(kind, name, parent, template)
      end
    end })
    ctl.ns.Options.open()
    H.contains(ctl.chatText(), 'Options panel unavailable')
    H.falsy(ctl.ns.MinimapButton.isShown())
    H.truthy(#ctl.errors > 0)
  end)

  it('drags the minimap button and opens options from a right click', function()
    local ctl = WoW.start()
    local button = ctl.env.MemoryForeverMinimapButton
    button._scripts.OnEnter(button)
    H.contains(ctl.env.GameTooltip._lines, 'Drag to move.')
    button._scripts.OnLeave()
    button._scripts.OnDragStart(button)
    button._scripts.OnUpdate(button)
    local angle = ctl.ns.Settings.get('minimapAngle')
    H.truthy(angle)
    button._scripts.OnDragStop(button)
    button:Click('RightButton')
    H.eq(ctl.openedCategory, 'category:Memory Forever')
    ctl.env.MemoryForever_OnAddonCompartmentClick(nil, 'RightButton')
    H.noErrors(ctl)
  end)

  it('hooks the old tooltip scripts when the new processor is missing', function()
    local ctl = WoW.start({ configure = function(c)
      c.env.TooltipDataProcessor = nil
      c.env.GameTooltip.HasScript = function() return true end
    end })
    H.eq(ctl.ns.Tooltip.installed, 'HookScript')
    ctl.units.npc = DUGHAN
    ctl.event('GOSSIP_SHOW')
    local tip = ctl.env.GameTooltip
    tip._lines = {}
    tip._unit = 'npc'
    tip._scripts.OnTooltipSetUnit(tip)
    H.contains(tip._lines, 'Talked')
    ctl.itemNames = { [2589] = 'Linen Cloth' }
    ctl.ns.Repository.store('items', { 'Linen Cloth' }, 'loot', 1)
    tip._item = nil
    tip._lines = {}
    tip._scripts.OnTooltipSetItem(tip, { id = 2589 })
    H.contains(tip._lines, 'Looted')
  end)

  it('capitalizes an interaction the tooltip has no label for', function()
    local ctl = WoW.start()
    local memory = ctl.ns.Memory.new('zones', { 'Elwynn Forest' }, 'discover', {
      x = 1, first = '26-11-12|10|Elwynn Forest|Goldshire|0',
    })
    local tip = ctl.env.GameTooltip
    tip._lines = {}
    ctl.ns.Tooltip.addMemories(tip, { memory })
    H.contains(tip._lines, 'Discover')
  end)
end)

describe('Client gaps', function()
  it('stays quiet when a discovery or a death has no zone', function()
    local ctl = WoW.start()
    ctl.env.GetZoneText = function() return nil end
    ctl.env.GetSubZoneText = function() return nil end
    ctl.event('UI_INFO_MESSAGE', 0, 'Discovered Northshire Abbey: 50 experience gained')
    H.notContains(ctl.chatText(), 'You discovered')
    ctl.event('PLAYER_DEAD')
    H.eq(ctl.char().misc.others.die.x, 1)
    H.falsy(ctl.char().deaths['Elwynn Forest'])
  end)

  it('does not announce a profession when the client has no profession API', function()
    local ctl = WoW.start()
    ctl.env.GetProfessions = nil
    ctl.env.GetProfessionInfo = nil
    ctl.env.GetNumSkillLines = nil
    ctl.env.GetSkillLineInfo = nil
    ctl.ns.Professions.scan()
    H.notContains(ctl.chatText(), 'reached')
    H.noErrors(ctl)
  end)

  it('runs a delayed call immediately when C_Timer is missing, and reports a handler error', function()
    local ctl = WoW.start()
    ctl.env.C_Timer = nil
    ctl.env.C_EventUtils = nil
    ctl.env.GetTime = nil
    local ran = false
    ctl.ns.Events.after(5, function() ran = true end)
    H.truthy(ran)
    H.truthy(ctl.ns.Events.isValid('ZONE_CHANGED'))
    H.truthy(ctl.ns.Events.now() > 0)
    ctl.env.geterrorhandler = nil
    ctl.ns.Events.on('PLAYER_FLAGS_CHANGED', function() error('boom') end)
    ctl.event('PLAYER_FLAGS_CHANGED')
    H.contains(ctl.chatText(), 'boom')
  end)

  it('disables a tracker that cannot register, and one whose setup throws', function()
    local ctl = WoW.start()
    ctl.ns.Trackers.register('probe', {
      label = 'Probe',
      events = { 'COMBAT_LOG_EVENT_UNFILTERED' },
      setup = function() end,
    })
    ctl.ns.Trackers.enable('probe')
    H.eq(ctl.ns.Trackers.status.probe, 'cannot register COMBAT_LOG_EVENT_UNFILTERED')
    ctl.ns.Trackers.register('boom', {
      label = 'Boom',
      setup = function() error('nope') end,
    })
    ctl.ns.Trackers.enable('boom')
    H.eq(ctl.ns.Trackers.status.boom, 'setup failed')
    H.contains(ctl.errors, 'nope')
  end)

  it('refuses to start when the character cannot be identified', function()
    local ctl = WoW.start({ configure = function(c)
      c.env.UnitGUID = function() return nil end
    end })
    H.contains(ctl.chatText(), 'Could not identify the character')
    H.falsy(ctl.ns.Repository.isReady())
  end)

  it('prints a toast in chat when the toast frame cannot be built, and hides it without a fade', function()
    local broken = WoW.start()
    local create = broken.env.CreateFrame
    broken.env.CreateFrame = function() error('toast broke') end
    broken.ns.Toast.show('Goldshire', 'Hello')
    H.contains(broken.chatText(), 'Goldshire - Hello')
    broken.env.CreateFrame = create

    local ctl = WoW.start()
    ctl.env.UIFrameFadeOut = nil
    ctl.ns.Toast.show(nil, 'Plain')
    ctl.runTimers()
    H.falsy(ctl.ns.Toast.isShown())
  end)

  it('stores time on a place that has no visit yet', function()
    local ctl = WoW.start()
    ctl.ns.Repository.addPlaceTime('Unvisited Wilds', nil, 90)
    H.eq(ctl.ns.Repository.placeSeconds('Unvisited Wilds'), 90)
  end)

  it('uses the quiet fallbacks when a piece of the client is missing', function()
    local named = WoW.start({ configure = function(c)
      c.env.C_AddOns = nil
      c.env.GetAddOnMetadata = nil
      c.env.TooltipDataProcessor = nil
      c.env.GameTooltip.HasScript = function() return false end
    end })
    H.eq(named.ns.VERSION, 'dev')
    H.eq(named.ns.Tooltip.installed, nil)
    named.units.pet = { guid = 'Pet-1-1', name = 'Wolf' }
    H.eq(named.ns.Tooltip.unitKey('pet'), nil)
    named.env.DEFAULT_CHAT_FRAME = nil
    named.ns.print('hello fallback')
    H.contains(named.chatText(), 'hello fallback')

    local stored, err = named.ns.Settings.set('minimapButton', 'maybe')
    H.eq(stored, nil)
    H.eq(err, 'expected on/off')

    local early = WoW.start({ login = false })
    local pending, why = early.ns.Settings.set('printChance', '0.2')
    H.eq(pending, nil)
    H.eq(why, 'saved data is not loaded yet')

    local ctl = WoW.start()
    ctl.ns.Journal.open()
    for _, frame in ipairs(ctl.frames) do
      if frame._text == 'NPCs' and frame._scripts.OnClick then frame:Click() end
    end
    H.eq(ctl.ns.Journal.tab, 'npcs')
    ctl.env.C_Item.GetItemInfo = function() return nil end
    ctl.event('CHAT_MSG_LOOT', 'You receive loot: item:999.')
    H.falsy(ctl.char().items['item:999.'])
    ctl.ns.db.moments = 'broken'
    H.eq(#ctl.ns.Moments.all(), 0)
  end)

  it('picks the other reminder sentences, including one with no previous time', function()
    local ctl = WoW.start()
    local verbs = { past = 'spoke', pastConnector = 'with', present = 'speak', presentConnector = 'with', subject = 'Marshal Dughan' }
    local memory = ctl.ns.Memory.new('npcs', { 'Marshal Dughan' }, 'talk', {
      first = '26-10-02|5|Elwynn Forest|Goldshire|0',
      last = '26-11-11|9|Elwynn Forest|Goldshire|0',
      x = 4,
    })
    ctl.randomValue = 0
    H.contains(ctl.ns.Formatter.random(memory, verbs), 'was on')
    ctl.randomValue = 0.4
    H.contains(ctl.ns.Formatter.random(memory, verbs), 'The last time I spoke with')
    ctl.randomValue = 0.6
    H.contains(ctl.ns.Formatter.random(memory, verbs), 'was yesterday')
    local empty = ctl.ns.Memory.new('npcs', { 'Marshal Dughan' }, 'talk', nil)
    H.contains(ctl.ns.Formatter.lastWithDate(empty, verbs), 'This is the 1st time')
    local lines = ctl.ns.Queries.lines('npcs')
    ctl.units.npc = DUGHAN
    ctl.event('QUEST_COMPLETE')
    ctl.event('QUEST_TURNED_IN', 123, 100, 0)
    local found = false
    for _, entry in ipairs(ctl.ns.Queries.entries('npcs')) do
      if entry.label == 'Marshal Dughan' then
        found = true
        H.contains(ctl.ns.Queries.formatEntry(entry), '1 quest')
      end
    end
    H.truthy(found)
    H.eq(type(lines), 'table')
  end)
end)
