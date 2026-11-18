local H, WoW = ...
local describe, it = H.describe, H.it

-- SavedVariables as written by the original Memory 1.6.0
local function legacySaved()
  return {
    MemoryAddon_DataSet = {
      ['Forever Realm'] = {
        ['Player-1-00000001'] = {
          misc = { login = { first = '24-08-01|1|-|-|0', last = '24-08-20|20|-|-|1', x = 30 },
                   others = { die = { first = '24-08-02|3|Elwynn Forest|Goldshire|0', last = '24-08-19|19|Duskwood|Darkshire|1', x = 7 } } },
          npcs = { ['Marshal Dughan'] = { talk = { first = '24-08-01|1|Elwynn Forest|Goldshire|0', last = '24-08-05|6|Elwynn Forest|Goldshire|0', x = 4 } } },
          players = {},
          zones = { ['Elwynn Forest'] = { subzones = { Goldshire = { visit = { first = '24-08-01|1|Elwynn Forest|Goldshire|0', last = '24-08-10|9|Elwynn Forest|Goldshire|1', x = 12 } } } } },
          items = { ['Linen Cloth'] = { loot = { first = '24-08-03|4|Elwynn Forest|Goldshire|0', last = '24-08-04|5|Elwynn Forest|Goldshire|0', x = 9 } },
                    -- path created but never stored by the original's get()
                    ['Ghost'] = { loot = { first = -1, last = -1, x = 0 } } },
          levels = { [2] = { date = '24-08-01', zone = 'Elwynn Forest', subZone = 'Northshire', moment = 0 } },
        },
      },
    },
    MemoryAddon_Settings = { moments = { 'Leveling with Sam' }, ['memory.printChance'] = '0.5', ['memory.showInTooltips'] = '0' },
  }
end

describe('SavedVariables', function()
  it('creates a fresh schema-2 database', function()
    local ctl = WoW.start()
    local db = ctl.env.MemoryForeverDB
    H.eq(db.schemaVersion, 3)
    H.eq(type(db.settings), 'table')
    H.eq(type(db.moments), 'table')
    H.truthy(ctl.char())
    H.eq(ctl.char().meta.name, 'Tester')
  end)

  it('imports the original Memory data into an empty database', function()
    local ctl = WoW.start({ saved = legacySaved() })
    H.noErrors(ctl)
    local char = ctl.char()
    H.eq(char.npcs['Marshal Dughan'].talk.x, 4)
    H.eq(char.zones['Elwynn Forest'].subzones.Goldshire.visit.x >= 12, true)
    H.eq(char.levels[2].subZone, 'Northshire')
    H.eq(ctl.env.MemoryForeverDB.moments[1], 'Leveling with Sam')
    H.eq(ctl.char().currentMoment, 1)
    H.eq(ctl.ns.Moments.current(), 'Leveling with Sam')
    H.eq(ctl.ns.Settings.get('printChance'), 0.5)
    H.eq(ctl.ns.Settings.get('showInTooltips'), false)
    H.eq(ctl.env.MemoryAddon_DataSet, nil, 'legacy variable cleared after import')
    H.contains(ctl.chatText(), 'Imported memories for 1 character')
    -- the never-stored placeholder doesn't show up
    H.eq(#ctl.ns.Repository.list('items', { 'Ghost' }), 0)
    H.eq(#ctl.ns.Repository.list('items', { 'Linen Cloth' }), 1)
  end)

  it('does not import into a database that already has memories', function()
    local first = WoW.start()
    local saved = first.saved()
    local legacy = legacySaved()
    saved.MemoryAddon_DataSet = legacy.MemoryAddon_DataSet
    local ctl = WoW.start({ saved = saved })
    H.noErrors(ctl)
    H.eq(ctl.char().npcs['Marshal Dughan'], nil)
  end)

  it('upgrades a database that has memories but no schema version', function()
    local ctl = WoW.start({ saved = { MemoryForeverDB = {
      realms = { ['Forever Realm'] = { ['Player-1-00000001'] = {
        npcs = { Bob = { talk = { first = '24-08-01|1|Elwynn Forest|Goldshire|0', last = '24-08-01|1|Elwynn Forest|Goldshire|0', x = 2 } } },
      } } },
    } } })
    H.noErrors(ctl)
    H.eq(ctl.env.MemoryForeverDB.schemaVersion, 3)
    H.eq(ctl.char().npcs.Bob.talk.x, 2)
  end)

  it('keeps a Memory 1.x import whose realm and GUID are not this character', function()
    local saved = legacySaved()
    saved.MemoryAddon_DataSet = {
      Azeroth = {
        ['Player-9-OLD'] = saved.MemoryAddon_DataSet['Forever Realm']['Player-1-00000001'],
      },
    }
    local ctl = WoW.start({ saved = saved })
    H.noErrors(ctl)
    H.contains(ctl.chatText(), 'Imported memories for 1 character')
    H.eq(ctl.char().npcs['Marshal Dughan'], nil)
    local stored = ctl.env.MemoryForeverDB.realms.Azeroth['Player-9-OLD']
    H.eq(stored.npcs['Marshal Dughan'].talk.x, 4)
    H.eq(ctl.env.MemoryAddon_DataSet, nil)
  end)

  it('leaves the legacy file alone when no rows or settings can be copied', function()
    local junk = { [true] = { nope = true } }
    local ctl = WoW.start({ saved = { MemoryAddon_DataSet = junk } })
    H.noErrors(ctl)
    H.eq(type(ctl.env.MemoryAddon_DataSet), 'table')
    H.notContains(ctl.chatText(), 'Imported memories')
  end)

  it('leaves data from a newer schema alone', function()
    local ctl = WoW.start({ saved = { MemoryForeverDB = { schemaVersion = 99, realms = {}, settings = {}, moments = {} } } })
    H.noErrors(ctl)
    H.eq(ctl.env.MemoryForeverDB.schemaVersion, 99)
    H.contains(ctl.chatText(), 'newer version')
  end)

  it('repairs mistyped tables', function()
    local ctl = WoW.start({ saved = { MemoryForeverDB = { schemaVersion = 2, realms = 'x', settings = 5, moments = { 1, 'b' } } } })
    H.noErrors(ctl)
    local db = ctl.env.MemoryForeverDB
    H.eq(type(db.realms), 'table')
    H.eq(db.moments[1], '1')
  end)

  it('keeps an existing account moment current for characters already saved', function()
    local ctl = WoW.start({ saved = { MemoryForeverDB = {
      schemaVersion = 2,
      moments = { 'Leveling with Sam' },
      settings = {},
      realms = { ['Forever Realm'] = { ['Player-1-00000001'] = { npcs = {} } } },
    } } })
    H.noErrors(ctl)
    H.eq(ctl.env.MemoryForeverDB.schemaVersion, 3)
    H.eq(ctl.ns.Moments.current(), 'Leveling with Sam')
  end)

  it('does not copy the current moment onto another character', function()
    local ctl = WoW.start()
    ctl.ns.Moments.add('On Tester')
    ctl.ns.Repository.bind('Forever Realm', 'Player-9-ALT', 'Alt', 'MAGE')
    H.eq(ctl.ns.Moments.current(), nil)
    ctl.ns.Moments.add('On Alt')
    local realm = ctl.env.MemoryForeverDB.realms['Forever Realm']
    H.eq(realm['Player-1-00000001'].currentMoment, 1)
    H.eq(realm['Player-9-ALT'].currentMoment, 2)
    H.eq(ctl.ns.Moments.current(), 'On Alt')
  end)

  it('only saves plain values (no secrets or functions)', function()
    local ctl = WoW.start()
    ctl.restricted = true
    ctl.units.target = { guid = 'Creature-0-1-2-3-99-0001', name = 'Kobold', canAttack = true }
    ctl.event('PLAYER_REGEN_DISABLED')
    ctl.event('PLAYER_REGEN_ENABLED')
    ctl.event('PLAYER_DEAD')
    ctl.moveTo('Westfall', 'Sentinel Hill')
    WoW.serialize(ctl.env.MemoryForeverDB)
    H.noErrors(ctl)
  end)

  it('says when the Forever build changes, and only on the login that sees it', function()
    local first = WoW.start()
    H.notContains(first.chatText(), 'updated from build')
    first.slash('status')
    H.contains(first.chatText(), 'Forever build 70009, checked on this client.')
    local second = WoW.start({ saved = first.saved(), configure = function(c) c.build = '70100' end })
    H.contains(second.chatText(), 'updated from build 70009 to 70100')
    H.contains(second.chatText(), 'has not been smoked')
    H.contains(second.chatText(), 'Memories are still saved')
    local third = WoW.start({ saved = second.saved(), configure = function(c) c.build = '70100' end })
    H.notContains(third.chatText(), 'updated from build')
    third.slash('status')
    H.contains(third.chatText(), 'Forever build 70100')
    H.contains(third.chatText(), 'not smoked on this client')
  end)

  it('says once when the first seen build is not the checked build', function()
    local first = WoW.start({ configure = function(c) c.build = '70150' end })
    H.contains(first.chatText(), 'This Forever client is build 70150')
    H.contains(first.chatText(), 'has not been smoked')
    local second = WoW.start({ saved = first.saved(), configure = function(c) c.build = '70150' end })
    H.notContains(second.chatText(), 'has not been smoked')
  end)

  it('says when the interface changes on the checked build', function()
    local first = WoW.start()
    local second = WoW.start({ saved = first.saved(), configure = function(c) c.interface = 16002 end })
    H.contains(second.chatText(), "interface changed from 16001 to 16002")
    H.contains(second.chatText(), 'has not been smoked')
  end)

  it('restores a character the saved file lost', function()
    local first = WoW.start()
    first.moveTo('Elwynn Forest', 'Goldshire')
    first.ns.DB.commit()
    local saved = first.saved()
    local guid = 'Player-1-00000001'
    local kept = saved.MemoryForeverDB_Backup.realms['Forever Realm'][guid]
    kept.zones['Elwynn Forest'].subzones.Goldshire.visit.x = 5
    H.eq(kept.zones['Elwynn Forest'].subzones.Goldshire.visit.x, 5)
    saved.MemoryForeverDB.realms['Forever Realm'][guid] = nil
    local second = WoW.start({ saved = saved })
    H.noErrors(second)
    H.contains(second.chatText(), 'Restored memories that were missing')
    H.eq(second.char().zones['Elwynn Forest'].subzones.Goldshire.visit.x >= 5, true)
  end)

  it('puts a lowered count back from the saved copy', function()
    local first = WoW.start()
    first.moveTo('Elwynn Forest', 'Goldshire')
    first.ns.DB.commit()
    local saved = first.saved()
    local visit = saved.MemoryForeverDB.realms['Forever Realm']['Player-1-00000001'].zones['Elwynn Forest'].subzones.Goldshire.visit
    local backupVisit = saved.MemoryForeverDB_Backup.realms['Forever Realm']['Player-1-00000001'].zones['Elwynn Forest'].subzones.Goldshire.visit
    backupVisit.x = 5
    visit.x = 0
    local second = WoW.start({ saved = saved })
    H.eq(second.char().zones['Elwynn Forest'].subzones.Goldshire.visit.x >= 5, true)
  end)

  it('restores the last copy when the saved file is not a table', function()
    local first = WoW.start()
    first.moveTo('Elwynn Forest', 'Goldshire')
    first.ns.DB.commit()
    local saved = first.saved()
    saved.MemoryForeverDB_Backup.realms['Forever Realm']['Player-1-00000001'].zones['Elwynn Forest'].subzones.Goldshire.visit.x = 5
    saved.MemoryForeverDB = 'garbage'
    local second = WoW.start({ saved = saved })
    H.noErrors(second)
    H.contains(second.chatText(), 'Restored the last copy')
    H.eq(second.char().zones['Elwynn Forest'].subzones.Goldshire.visit.x >= 5, true)
  end)

  it('does not advance the schema when a migration fails', function()
    local ctl = WoW.start()
    ctl.char().npcs.Bob = { talk = { first = '24-08-01|1|Elwynn Forest|Goldshire|0', last = '24-08-01|1|Elwynn Forest|Goldshire|0', x = 2 } }
    ctl.env.MemoryForeverDB.schemaVersion = 2
    local original = ctl.ns.DB.MIGRATIONS[3]
    ctl.ns.DB.MIGRATIONS[3] = function() error('boom') end
    ctl.ns.DB.init()
    ctl.ns.DB.MIGRATIONS[3] = original
    H.eq(ctl.env.MemoryForeverDB.schemaVersion, 2)
    H.eq(ctl.char().npcs.Bob.talk.x, 2)
    H.contains(ctl.ns.pendingNotices[1], 'Memories were left as they are')
    H.noErrors(ctl)
  end)

  it('strips a value the client cannot save and keeps the memories', function()
    local ctl = WoW.start()
    ctl.moveTo('Elwynn Forest', 'Goldshire')
    ctl.char().npcs.Bad = function() end
    ctl.ns.DB.commit()
    WoW.serialize(ctl.env.MemoryForeverDB)
    WoW.serialize(ctl.env.MemoryForeverDB_Backup)
    H.eq(ctl.char().npcs.Bad, nil)
    H.eq(ctl.char().zones['Elwynn Forest'].subzones.Goldshire.visit.x >= 1, true)
    H.noErrors(ctl)
  end)
end)

describe('MemoryString', function()
  local ctl = WoW.start()
  local MS = ctl.ns.MemoryString

  it('parses the original format', function()
    local s = MS.parse('24-08-01|5|Elwynn Forest|Goldshire|2')
    H.eq(s.level, 5)
    H.eq(s.zone, 'Elwynn Forest')
    H.eq(s.moment, 2)
    H.eq(s:location(), 'Goldshire, Elwynn Forest')
    H.eq(MS.parse(-1), nil)
    H.eq(MS.parse('garbage'), nil)
    local old = MS.parse('24-08-01|5|Elwynn Forest|-')
    H.eq(old.subZone, nil)
    H.eq(old.moment, nil)
  end)

  it('captures and round-trips, escaping the separator', function()
    ctl.zone, ctl.subzone = 'Odd|Zone', ''
    local s = MS.capture()
    local again = MS.parse(s:toString())
    H.eq(again.zone, 'Odd/Zone')
    H.eq(again.subZone, nil)
    H.eq(again.level, 10)
  end)
end)

describe('Settings', function()
  local ctl = WoW.start()
  local S = ctl.ns.Settings

  it('coerces values and accepts the original keys', function()
    H.eq(S.set('memory.printChance', '25%'), 0.25)
    H.eq(S.get('printChance'), 0.25)
    H.eq(S.set('printChance', '7'), 1, 'clamped')
    H.eq(S.set('showInTooltips', 'off'), false)
    H.eq(S.set('reminderStyle', 'TOAST'), 'toast')
    local value, err = S.set('reminderStyle', 'loud')
    H.eq(value, nil)
    H.contains(err, 'chat')
    H.eq(S.set('nope', 1), nil)
  end)

  it('falls back to defaults for bad stored values', function()
    ctl.env.MemoryForeverDB.settings.printChance = 'abc'
    H.eq(S.get('printChance'), 0.2)
  end)
end)
