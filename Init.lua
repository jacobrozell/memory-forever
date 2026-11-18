--[[
Startup: SavedVariables on ADDON_LOADED, everything else on PLAYER_LOGIN
(when the player's GUID, realm and level are available).
]]
local ADDON, ns = ...

local started = false

local function guard(fn)
  local ok, err = pcall(fn)
  if not ok then ns.Events.report(err) end
end

local function flushNotices()
  for _, message in ipairs(ns.pendingNotices or {}) do ns.print(message) end
  ns.pendingNotices = nil
end

local function start()
  if started then return end
  ns.DB.init()
  if ns.Client then ns.Client.note(ns.db) end

  local realm = ns.Safe.str(ns.Safe.api('GetRealmName'))
  local guid = ns.Safe.unitGUID('player')
  if not realm or not guid then
    ns.print('Could not identify the character. Memories are off for this session.')
    flushNotices()
    return
  end
  local name = ns.Safe.unitName('player')
  local _, class = ns.Safe.api('UnitClass', 'player')
  ns.Repository.bind(realm, guid, name, class)
  started = true

  guard(function() ns.Trackers.enableAll() end)
  guard(function() ns.Tooltip.setup() end)
  guard(function() ns.Options.setup() end)
  guard(function() ns.MinimapButton.update() end)
  guard(function()
    ns.record({ category = 'misc', path = {}, interaction = 'login', quiet = true })
  end)
  guard(function() ns.DB.commit() end)

  ns.print(ns.VERSION .. ' loaded. Type ' .. ns.highlight('/mem') .. ' to open the journal.')
  flushNotices()
  ns.debug('started ' .. ns.VERSION)
end

ns.Events.on('ADDON_LOADED', function(_, loaded)
  if loaded == ADDON then ns.DB.init() end
end)

ns.Events.on('PLAYER_LOGIN', start)

ns.Events.on('PLAYER_LOGOUT', function()
  if ns.DB and ns.DB.commit then ns.DB.commit() end
end)

ns.start = start
