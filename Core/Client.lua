--[[
The Forever client this copy was checked on, and a one-time note when the
client build or interface changes.

GetBuildInfo's second return is the build (70009). The fourth is the TOC
interface (16001). Update TESTED_BUILD and the changelog together when a
smoke on a new build passes.
]]
local _, ns = ...

local Client = {}
ns.Client = Client

Client.TESTED_BUILD = '70009'
Client.TESTED_INTERFACE = '16001'

local function text(value)
  if ns.Safe.isSecret(value) then return nil end
  if type(value) == 'number' then
    if value ~= value or value == math.huge or value == -math.huge then return nil end
    return tostring(value)
  end
  if type(value) ~= 'string' or value == '' then return nil end
  return value
end

--[[
version, build, date, interface. Missing GetBuildInfo yields empty strings.
]]
function Client.read()
  local version, build, date, interface = ns.Safe.api('GetBuildInfo')
  return {
    version = text(version),
    build = text(build),
    date = text(date),
    interface = text(interface),
  }
end

local function remember(db, info)
  if type(db.client) ~= 'table' then db.client = {} end
  local previous = {
    build = text(db.client.build),
    interface = text(db.client.interface),
  }
  if info.build then db.client.build = info.build end
  if info.version then db.client.version = info.version end
  if info.interface then db.client.interface = info.interface end
  db.client.tested = Client.TESTED_BUILD
  return previous
end

--[[
Stores the build on the database. The first login on a build only records it.
A later login whose build or interface moved, and that this version was not
checked on, queues one notice.
]]
function Client.note(db)
  if type(db) ~= 'table' then return end
  local version = tonumber(db.schemaVersion)
  if version and ns.DB and version > ns.DB.SCHEMA_VERSION then return end
  local info = Client.read()
  local previous = remember(db, info)
  local unchecked = info.build ~= Client.TESTED_BUILD or (info.interface and info.interface ~= Client.TESTED_INTERFACE)
  if not previous.build and not previous.interface then
    if unchecked and info.build then
      ns.pendingNotices = ns.pendingNotices or {}
      table.insert(ns.pendingNotices, 'This Forever client is build ' .. info.build
        .. '. This version was checked on build ' .. Client.TESTED_BUILD
        .. ' and has not been smoked on this client. Memories are still saved.'
        .. ' /mem status lists anything that turned off.')
    end
    return
  end

  local buildChanged = info.build and previous.build and info.build ~= previous.build
  local interfaceChanged = info.interface and previous.interface and info.interface ~= previous.interface
  if not buildChanged and not interfaceChanged then return end
  if info.build == Client.TESTED_BUILD and (not info.interface or info.interface == Client.TESTED_INTERFACE) then
    return
  end

  local line
  if buildChanged then
    line = 'Forever updated from build ' .. previous.build .. ' to ' .. info.build .. '.'
  else
    line = 'Forever\'s interface changed from ' .. previous.interface .. ' to ' .. info.interface .. '.'
  end
  if interfaceChanged and buildChanged then
    line = line .. ' Interface changed from ' .. previous.interface .. ' to ' .. info.interface .. '.'
  end
  line = line .. ' This version was checked on build ' .. Client.TESTED_BUILD
    .. ' and has not been smoked on this client. Memories are still saved.'
    .. ' /mem status lists anything that turned off.'
  ns.pendingNotices = ns.pendingNotices or {}
  table.insert(ns.pendingNotices, line)
end

--[[
One line for /mem status.
]]
function Client.summary()
  local info = Client.read()
  local build = info.build
  if not build and ns.db and type(ns.db.client) == 'table' then build = text(ns.db.client.build) end
  build = build or 'unknown'
  if build == Client.TESTED_BUILD then
    return 'Forever build ' .. build .. ', checked on this client.'
  end
  return 'Forever build ' .. build .. '. Checked on ' .. Client.TESTED_BUILD .. ', not smoked on this client.'
end
