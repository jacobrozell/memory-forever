--[[
SavedVariables initialization and schema migrations.

MemoryForeverDB = {
  schemaVersion = 3,
  settings = { [name] = value },            -- account-wide, see Data/Settings.lua
  moments  = { 'label', ... },              -- account-wide catalog; index is stored in memories
                                            -- each character's currentMoment picks one label
  realms   = {
    [realmName] = {
      [playerGUID] = {
        meta    = { name = 'Name', class = 'WARRIOR' },
        misc    = { others = { die = leaf }, login = leaf, achievements = { [name] = { earn = leaf } } },
        npcs    = { [npcName]  = { talk = leaf, business = leaf, fight = leaf, quest = leaf } },
        players = { [Name-Realm] = { party = leaf } },
        zones   = { [zone] = { visit = leaf, subzones = { [subzone] = { visit = leaf } } } },
        items   = { [itemName] = { loot = leaf } },
        deaths  = { [zone] = { [subzone or zone] = { die = leaf } } },
        levels  = { [level] = { date, zone, subZone, moment } },
      },
    },
  },
}
leaf = { first = MemoryString, last = MemoryString, x = count }

Schema versions:
  0 - nothing saved yet
  1 - the original Memory addon (MemoryAddon_DataSet / MemoryAddon_Settings)
  2 - Memory Forever 2.0, one current moment for the whole account
  3 - current moment is per character (currentMoment on the character)

The init is defensive: it runs on ADDON_LOADED and again on PLAYER_LOGIN, and
repairs missing or mistyped tables instead of assuming the file loaded (the
Forever beta sometimes failed to load addon settings).

MemoryForeverDB_Backup is a second copy, written on login and on logout.
A character or a count missing from the main file is copied back from it.
A migration runs on a copy and is kept only when it finishes. The legacy
SavedVariables are cleared only after that copy is the database we keep.
]]
local _, ns = ...

local DB = {}
ns.DB = DB

DB.SCHEMA_VERSION = 3

local function isFinite(value)
  return type(value) == 'number' and value == value and value > -math.huge and value < math.huge
end

local function notice(text)
  ns.pendingNotices = ns.pendingNotices or {}
  table.insert(ns.pendingNotices, text)
end

--[[
Keeps a value we are about to stop using, when the client can still save it.
]]
function DB.preserve(db, label, value)
  if type(db) ~= 'table' or value == nil or not DB.canSave(value) then return end
  if type(db.preserved) ~= 'table' then db.preserved = {} end
  if #db.preserved >= 30 then return end
  table.insert(db.preserved, { label = tostring(label), value = ns.Util.copy(value) })
end

local function ensureTable(parent, key)
  if type(parent[key]) ~= 'table' then
    if parent[key] ~= nil then DB.preserve(parent, key, parent[key]) end
    parent[key] = {}
  end
  return parent[key]
end

--[[
Repairs the top-level shape. Safe to call any number of times. A value that
is not a table is kept under preserved instead of being deleted.
]]
function DB.ensureShape(db)
  ensureTable(db, 'settings')
  ensureTable(db, 'realms')
  local moments = ensureTable(db, 'moments')
  for i = #moments, 1, -1 do
    if type(moments[i]) ~= 'string' then moments[i] = tostring(moments[i]) end
  end
  for realm, players in pairs(db.realms) do
    if type(players) ~= 'table' then
      DB.preserve(db, 'realm:' .. tostring(realm), players)
      db.realms[realm] = nil
    end
  end
  return db
end

--[[
Imports the original Memory addon's SavedVariables when they're present
(the user copied the old SavedVariables file, see README) and this database
has no character data yet. Returns the number of characters imported.
]]
function DB.importLegacy(db)
  local legacyData = MemoryAddon_DataSet
  local legacySettings = MemoryAddon_Settings
  if type(legacyData) ~= 'table' and type(legacySettings) ~= 'table' then return 0 end

  if next(db.realms) ~= nil then
    db.legacyImportSkipped = true
    return 0
  end

  local characters = 0
  local copiedRows = false
  if type(legacyData) == 'table' then
    for realm, players in pairs(legacyData) do
      if type(realm) == 'string' and type(players) == 'table' then
        db.realms[realm] = ns.Util.copy(players)
        copiedRows = true
        for _ in pairs(players) do characters = characters + 1 end
      end
    end
  end

  local copiedSettings = false
  if type(legacySettings) == 'table' then
    if type(legacySettings.moments) == 'table' and #db.moments == 0 then
      for _, moment in ipairs(legacySettings.moments) do
        table.insert(db.moments, tostring(moment))
        copiedSettings = true
      end
    end
    for oldKey, newKey in pairs(ns.Settings.ALIASES) do
      if legacySettings[oldKey] ~= nil and db.settings[newKey] == nil then
        db.settings[newKey] = legacySettings[oldKey]
        copiedSettings = true
      end
    end
  end

  -- a file we could not read must stay on disk so it can be tried again
  if not copiedRows and not copiedSettings then return 0 end

  db.importedFrom = 'Memory 1.x'
  return characters
end

DB.MIGRATIONS = {
  -- 0/1 -> 2: create the new layout and import the original addon's data
  [2] = function(db)
    DB.ensureShape(db)
    local imported = DB.importLegacy(db)
    if imported > 0 then
      ns.pendingNotices = ns.pendingNotices or {}
      table.insert(ns.pendingNotices, 'Imported memories for ' .. ns.Util.plural(imported, 'character') .. ' from the original Memory addon.')
    end
  end,
  -- The last label used to be current for every character. Keep that for
  -- characters that already exist, then let each one move on its own.
  [3] = function(db)
    DB.ensureShape(db)
    local count = #db.moments
    if count < 1 then return end
    for _, players in pairs(db.realms) do
      if type(players) == 'table' then
        for _, char in pairs(players) do
          if type(char) == 'table' and char.currentMoment == nil then
            char.currentMoment = count
          end
        end
      end
    end
  end,
}

local function detectVersion(db)
  local version = tonumber(db.schemaVersion)
  if version then return version end
  if next(db) == nil then return 0 end
  return 1
end

local function replaceContents(target, source)
  for key in pairs(target) do target[key] = nil end
  for key, value in pairs(source) do target[key] = value end
end

--[[
True when the client can write this value into SavedVariables.
]]
function DB.canSave(value, seen)
  local kind = type(value)
  if kind == 'string' or kind == 'boolean' then return true end
  if kind == 'number' then return isFinite(value) end
  if kind ~= 'table' then return false end
  seen = seen or {}
  if seen[value] then return false end
  seen[value] = true
  for key, child in pairs(value) do
    if (type(key) ~= 'string' and not isFinite(key)) or not DB.canSave(child, seen) then
      return false
    end
  end
  return true
end

--[[
Drops functions, secret values and other values the client cannot save.
Tables that hold real memories are kept. One bad value must not discard the file.
]]
function DB.sanitize(value, seen)
  if type(value) ~= 'table' then return end
  seen = seen or {}
  if seen[value] then return end
  seen[value] = true
  for key, child in pairs(value) do
    local keyOk = type(key) == 'string' or isFinite(key)
    local childOk = type(child) == 'table' or type(child) == 'string' or type(child) == 'boolean' or isFinite(child)
    if not keyOk or not childOk then
      value[key] = nil
    elseif type(child) == 'table' then
      DB.sanitize(child, seen)
    end
  end
end

local function isLeaf(value)
  return type(value) == 'table' and type(value.x) == 'number'
end

local function clearLegacy()
  if type(MemoryAddon_DataSet) == 'table' then MemoryAddon_DataSet = nil end
  if type(MemoryAddon_Settings) == 'table' then MemoryAddon_Settings = nil end
end

--[[
Runs each pending migration on a copy. The saved table changes only after that
copy finishes. A failure leaves the current schema and the current memories.
]]
function DB.migrate(db, version)
  for target = version + 1, DB.SCHEMA_VERSION do
    local migrate = DB.MIGRATIONS[target]
    if migrate then
      local copy = ns.Util.copy(db)
      local ok, err = pcall(migrate, copy)
      if not ok then
        if not ns.migrationFailed then
          ns.migrationFailed = true
          notice('Could not update saved data to schema ' .. target .. '. Memories were left as they are.')
        end
        return false
      end
      copy.schemaVersion = target
      replaceContents(db, copy)
      if db.importedFrom then clearLegacy() end
    else
      db.schemaVersion = target
    end
  end
  return true
end

--[[
How much memory is in a database: one per character, plus each stored count.
Used so an empty file never replaces a copy that still has characters.
]]
function DB.score(db)
  if type(db) ~= 'table' or type(db.realms) ~= 'table' then return 0 end
  local total = 0
  local function walk(node)
    if type(node) ~= 'table' then return end
    if isLeaf(node) then
      if isFinite(node.x) and node.x > 0 then total = total + node.x end
      return
    end
    for _, value in pairs(node) do walk(value) end
  end
  for _, players in pairs(db.realms) do
    if type(players) == 'table' then
      for _, char in pairs(players) do
        if type(char) == 'table' then
          total = total + 1
          walk(char)
        end
      end
    end
  end
  return total
end

local function mergeTree(primary, saved, restored)
  if type(primary) ~= 'table' or type(saved) ~= 'table' then return restored end
  for key, savedValue in pairs(saved) do
    if type(key) == 'string' or isFinite(key) then
      local current = primary[key]
      if isLeaf(savedValue) then
        if not isLeaf(current) or savedValue.x > current.x then
          primary[key] = ns.Util.copy(savedValue)
          restored = restored + 1
        elseif savedValue.x == current.x and ns.MemoryString
            and not ns.MemoryString.parse(current.first) and ns.MemoryString.parse(savedValue.first) then
          current.first = savedValue.first
          restored = restored + 1
        end
      elseif type(savedValue) == 'table' then
        if current == nil then
          primary[key] = ns.Util.copy(savedValue)
          restored = restored + 1
        elseif type(current) == 'table' and not isLeaf(current) then
          restored = mergeTree(current, savedValue, restored)
        end
      elseif type(savedValue) == 'number' and isFinite(savedValue) and type(current) == 'number' and savedValue > current then
        primary[key] = savedValue
        restored = restored + 1
      elseif current == nil and (type(savedValue) == 'string' or type(savedValue) == 'boolean' or isFinite(savedValue)) then
        primary[key] = savedValue
      end
    end
  end
  return restored
end

local function mergeLevels(primary, saved, restored)
  if type(saved) ~= 'table' then return restored end
  if type(primary) ~= 'table' then return restored end
  for level, data in pairs(saved) do
    if type(data) == 'table' and type(data.date) == 'string' and data.date ~= '' then
      local have = primary[level]
      if type(have) ~= 'table' or type(have.date) ~= 'string' or have.date == '' then
        primary[level] = ns.Util.copy(data)
        restored = restored + 1
      end
    end
  end
  return restored
end

local CATEGORIES = { 'misc', 'npcs', 'players', 'zones', 'items', 'deaths' }

local function mergeChar(primary, saved, restored)
  if type(saved.meta) == 'table' then
    if type(primary.meta) ~= 'table' then primary.meta = {} end
    if primary.meta.name == nil then primary.meta.name = saved.meta.name end
    if primary.meta.class == nil then primary.meta.class = saved.meta.class end
  end
  if primary.currentMoment == nil and (type(saved.currentMoment) == 'number' or type(saved.currentMoment) == 'string') then
    primary.currentMoment = saved.currentMoment
  end
  for _, category in ipairs(CATEGORIES) do
    if type(saved[category]) == 'table' then
      if type(primary[category]) ~= 'table' then
        primary[category] = ns.Util.copy(saved[category])
        restored = restored + 1
      else
        restored = mergeTree(primary[category], saved[category], restored)
      end
    end
  end
  if type(saved.levels) == 'table' then
    if type(primary.levels) ~= 'table' then primary.levels = {} end
    restored = mergeLevels(primary.levels, saved.levels, restored)
  end
  return restored
end

--[[
Copies anything the backup still has and the main file has lost: a missing
character, a higher count, a level date. Returns how many pieces came back.
Does not delete anything in the main file.
]]
function DB.recover(db, backup)
  if type(db) ~= 'table' or type(backup) ~= 'table' or type(backup.realms) ~= 'table' then return 0 end
  if type(db.realms) ~= 'table' then db.realms = {} end
  local restored = 0
  for realm, players in pairs(backup.realms) do
    if type(realm) == 'string' and type(players) == 'table' then
      if type(db.realms[realm]) ~= 'table' then
        if db.realms[realm] ~= nil then DB.preserve(db, 'realm:' .. realm, db.realms[realm]) end
        db.realms[realm] = ns.Util.copy(players)
        restored = restored + 1
      else
        for guid, char in pairs(players) do
          if (type(guid) == 'string' or isFinite(guid)) and type(char) == 'table' then
            local current = db.realms[realm][guid]
            if type(current) ~= 'table' then
              if current ~= nil then DB.preserve(db, tostring(realm) .. ':' .. tostring(guid), current) end
              db.realms[realm][guid] = ns.Util.copy(char)
              restored = restored + 1
            else
              restored = mergeChar(current, char, restored)
            end
          end
        end
      end
    end
  end
  if (type(db.moments) ~= 'table' or #db.moments == 0) and type(backup.moments) == 'table' and #backup.moments > 0 then
    db.moments = ns.Util.copy(backup.moments)
    restored = restored + 1
  end
  if type(db.settings) ~= 'table' then db.settings = {} end
  if type(backup.settings) == 'table' then
    for key, value in pairs(backup.settings) do
      if type(key) == 'string' and db.settings[key] == nil
          and (type(value) == 'string' or type(value) == 'boolean' or isFinite(value)) then
        db.settings[key] = value
      end
    end
  end
  return restored
end

local function attach()
  local backup = MemoryForeverDB_Backup
  local db = MemoryForeverDB
  if type(db) == 'table' then return db end
  if type(backup) == 'table' and type(backup.realms) == 'table' and next(backup.realms) ~= nil then
    db = ns.Util.copy(backup)
    MemoryForeverDB = db
    notice('Saved data did not load. Restored the last copy.')
    return db
  end
  db = {}
  MemoryForeverDB = db
  return db
end

--[[
Loads (or creates) MemoryForeverDB, runs pending migrations and exposes it as
ns.db. Idempotent. A newer schema is left untouched.
]]
function DB.init()
  local db = attach()
  local version = detectVersion(db)
  if version > DB.SCHEMA_VERSION then
    if not ns.notedNewerSchema then
      ns.notedNewerSchema = true
      notice('Saved data is from a newer version (schema ' .. version .. '). Some memories may not show.')
    end
  else
    DB.migrate(db, version)
    DB.ensureShape(db)
    local backup = MemoryForeverDB_Backup
    if type(backup) == 'table' then
      local ok, restored = pcall(DB.recover, db, backup)
      if not ok then
        notice('Could not compare the saved copy. Memories already loaded were left as they are.')
        ns.Events.report(restored)
      elseif type(restored) == 'number' and restored > 0 then
        notice('Restored memories that were missing from the saved file.')
      end
    end
  end
  ns.db = db
  return db
end

--[[
Removes values the client cannot save, puts back anything the backup still
has, then refreshes the backup when the main file is at least as complete.
An empty main file does not replace a backup that still has characters.
]]
function DB.commit()
  local db = MemoryForeverDB
  if type(db) ~= 'table' then return end
  DB.sanitize(db)
  local version = tonumber(db.schemaVersion) or 0
  local backup = MemoryForeverDB_Backup
  if version <= DB.SCHEMA_VERSION and type(backup) == 'table' then
    pcall(DB.recover, db, backup)
  end
  local backupScore = type(backup) == 'table' and DB.score(backup) or 0
  if DB.score(db) >= backupScore then
    MemoryForeverDB_Backup = ns.Util.copy(db)
  end
end
