local Framework = { name = nil, qb = nil }
local KeyCache = {}
local TemporaryKeys = {}
local reconnectGrace = {}

local function trim(value)
    if not value then return nil end
    return tostring(value):gsub('^%s*(.-)%s*$', '%1')
end

local function notify(src, msg, kind)
    if not Config.Notifications.enabled then return end
    TriggerClientEvent('shocks_vehiclekeys:client:notify', src, msg, kind or 'inform')
end

local function detectFramework()
    if Config.Framework == 'qbox' or (Config.Framework == 'auto' and GetResourceState(Config.QboxResource) == 'started') then
        Framework.name = 'qbox'
        return
    end
    if Config.Framework == 'qbcore' or (Config.Framework == 'auto' and GetResourceState(Config.QBCoreResource) == 'started') then
        Framework.name = 'qbcore'
        Framework.qb = exports[Config.QBCoreResource]:GetCoreObject()
        return
    end
    Framework.name = 'none'
end

detectFramework()

local function getPlayerData(src)
    if Framework.name == 'qbox' then
        local ok, player = pcall(function() return exports[Config.QboxResource]:GetPlayer(src) end)
        if ok and player then
            return player.PlayerData or player
        end
    elseif Framework.name == 'qbcore' and Framework.qb then
        local player = Framework.qb.Functions.GetPlayer(src)
        return player and player.PlayerData or nil
    end
    return nil
end

local function getCitizenId(src)
    local data = getPlayerData(src)
    return data and data.citizenid or nil
end

local function getLicense(src)
    local identifiers = GetPlayerIdentifiers(src)
    for i = 1, #identifiers do
        if identifiers[i]:sub(1, 8) == 'license:' then return identifiers[i] end
    end
    return identifiers[1]
end

local function vehiclePlate(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return nil end
    return trim(GetVehicleNumberPlateText(vehicle))
end

local function findVehicleNearPlayer(src, plate, radius)
    plate = trim(plate)
    if not plate then return 0 end
    local ped = GetPlayerPed(src)
    if ped == 0 or not DoesEntityExist(ped) then return 0 end
    local origin = GetEntityCoords(ped)
    for _, vehicle in ipairs(GetAllVehicles()) do
        if DoesEntityExist(vehicle) and vehiclePlate(vehicle) == plate then
            if #(origin - GetEntityCoords(vehicle)) <= (radius or 7.5) then
                return vehicle
            end
        end
    end
    return 0
end

local function isOwner(src, plate)
    local citizenid = getCitizenId(src)
    if not citizenid or not plate then return false end
    local row = MySQL.single.await(('SELECT 1 FROM player_vehicles WHERE citizenid = ? AND plate = ? LIMIT 1'):format(), { citizenid, plate })
    return row ~= nil
end

local function dbHasKey(src, plate)
    local citizenid = getCitizenId(src)
    if not citizenid or not plate then return false end
    local row = MySQL.single.await(('SELECT 1 FROM `%s` WHERE citizenid = ? AND plate = ? AND key_type = ? LIMIT 1'):format(Config.Persistence.databaseTable), { citizenid, plate, 'permanent' })
    return row ~= nil
end

local function hasAccess(src, plate)
    plate = trim(plate)
    if not plate then return false end
    if Config.Access.ownerHasKeys and isOwner(src, plate) then return true end
    if TemporaryKeys[src] and TemporaryKeys[src][plate] then return true end
    if Config.Access.permanentSharedKeys and dbHasKey(src, plate) then return true end
    return false
end

local function sendKeyList(src)
    if not DoesPlayerExist(src) then return end
    local citizenid = getCitizenId(src)
    if not citizenid then return end

    local keys = {}
    local owned = MySQL.query.await('SELECT plate FROM player_vehicles WHERE citizenid = ?', { citizenid }) or {}
    for i = 1, #owned do keys[trim(owned[i].plate)] = true end

    local shared = MySQL.query.await(('SELECT plate FROM `%s` WHERE citizenid = ? AND key_type = ?'):format(Config.Persistence.databaseTable), { citizenid, 'permanent' }) or {}
    for i = 1, #shared do keys[trim(shared[i].plate)] = true end

    TemporaryKeys[src] = TemporaryKeys[src] or {}
    for plate in pairs(TemporaryKeys[src]) do keys[plate] = true end

    KeyCache[src] = keys
    TriggerClientEvent('shocks_vehiclekeys:client:syncKeys', src, keys)
end

local function grantPermanentKey(target, plate, issuedBy, skipNotify)
    local cid = getCitizenId(target)
    plate = trim(plate)
    if not cid or not plate then return false end
    local exists = MySQL.single.await(('SELECT 1 FROM `%s` WHERE citizenid = ? AND plate = ? AND key_type = ? LIMIT 1'):format(Config.Persistence.databaseTable), { cid, plate, 'permanent' })
    if not exists then
        MySQL.insert.await(('INSERT INTO `%s` (citizenid, plate, key_type, issued_by) VALUES (?, ?, ?, ?)'):format(Config.Persistence.databaseTable), { cid, plate, 'permanent', issuedBy })
    end
    sendKeyList(target)
    if not skipNotify then notify(target, ('Keys added for %s.'):format(plate), 'success') end
    return true
end

local function removePermanentKey(target, plate, skipNotify)
    local cid = getCitizenId(target)
    plate = trim(plate)
    if not cid or not plate then return false end
    local affected = MySQL.update.await(('DELETE FROM `%s` WHERE citizenid = ? AND plate = ? AND key_type = ?'):format(Config.Persistence.databaseTable), { cid, plate, 'permanent' })
    if TemporaryKeys[target] then TemporaryKeys[target][plate] = nil end
    sendKeyList(target)
    if not skipNotify and affected and affected > 0 then notify(target, ('Keys removed for %s.'):format(plate), 'success') end
    return affected and affected > 0
end

local function setTemporaryKey(target, plate, state)
    TemporaryKeys[target] = TemporaryKeys[target] or {}
    plate = trim(plate)
    if not plate then return false end
    TemporaryKeys[target][plate] = state and true or nil
    sendKeyList(target)
    return true
end

local function getVehicleOwnerByPlate(plate)
    plate = trim(plate)
    if not plate then return nil end
    return MySQL.single.await('SELECT citizenid, license FROM player_vehicles WHERE plate = ? LIMIT 1', { plate })
end

local function validateNearbyVehicle(src, vehicle, distance)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    local ped = GetPlayerPed(src)
    if ped == 0 or not DoesEntityExist(ped) then return false end
    return #(GetEntityCoords(ped) - GetEntityCoords(vehicle)) <= (distance or Config.Vehicle.lockDistance)
end

local function serverGiveKeys(src, vehicle, skipNotify, force)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    local plate = vehiclePlate(vehicle)
    if not plate then return false end
    if not force and not hasAccess(src, plate) then return false end
    return grantPermanentKey(src, plate, getLicense(src), skipNotify)
end

local function serverRemoveKeys(src, vehicle, skipNotify, force)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    local plate = vehiclePlate(vehicle)
    if not plate then return false end
    if not force and not hasAccess(src, plate) then return false end
    return removePermanentKey(src, plate, skipNotify)
end

exports('GiveKeys', serverGiveKeys)
exports('GrantKeys', function(src, vehicle, skipNotify)
    return serverGiveKeys(src, vehicle, skipNotify, true)
end)
exports('RemoveKeys', serverRemoveKeys)
exports('HasKeys', function(src, vehicle)
    return vehicle and hasAccess(src, vehiclePlate(vehicle)) or false
end)
exports('GiveKeysByPlate', function(src, plate, skipNotify)
    plate = trim(plate)
    if not plate then return false end
    if not hasAccess(src, plate) then return false end
    return grantPermanentKey(src, plate, getLicense(src), skipNotify)
end)
exports('RemoveKeysByPlate', function(src, plate, skipNotify)
    return removePermanentKey(src, plate, skipNotify)
end)
local function normalizeLockState(state)
    if state == 'lock' or state == 'locked' then return 2 end
    if state == 'unlock' or state == 'unlocked' then return 1 end
    return tonumber(state) or 1
end

exports('SetLockState', function(vehicle, state)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    local lockState = normalizeLockState(state)
    Entity(vehicle).state:set('shocks_vehiclekeys_lock', lockState, true)
    return true
end)

RegisterNetEvent('shocks_vehiclekeys:server:requestSync', function()
    sendKeyList(source)
end)

RegisterNetEvent('shocks_vehiclekeys:server:giveKeys', function(target, plate, permanent)
    local src = source
    target = tonumber(target)
    plate = trim(plate)
    if not target or not plate or target == src or not DoesPlayerExist(target) then return end
    local giverPed, targetPed = GetPlayerPed(src), GetPlayerPed(target)
    if giverPed == 0 or targetPed == 0 then return end
    if #(GetEntityCoords(giverPed) - GetEntityCoords(targetPed)) > 5.0 then
        notify(src, 'The player receiving the keys is too far away.', 'error')
        return
    end
    if findVehicleNearPlayer(src, plate, Config.Vehicle.lockDistance + 2.5) == 0 then
        notify(src, 'The vehicle must be nearby before you can share its keys.', 'error')
        return
    end
    if not hasAccess(src, plate) then
        notify(src, 'You do not have the keys to this vehicle.', 'error')
        return
    end
    if permanent == false and Config.Access.temporaryKeys then
        setTemporaryKey(target, plate, true)
        notify(target, ('Temporary keys received for %s.'):format(plate), 'success')
    else
        grantPermanentKey(target, plate, getLicense(src), false)
    end
end)

RegisterNetEvent('shocks_vehiclekeys:server:acquire', function(netId)
    local src = source
    local vehicle = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if vehicle == 0 or not validateNearbyVehicle(src, vehicle, Config.Vehicle.lockDistance) then return end
    local plate = vehiclePlate(vehicle)
    if plate and isOwner(src, plate) then
        grantPermanentKey(src, plate, getLicense(src), true)
    elseif plate and reconnectGrace[src] and reconnectGrace[src][plate] and reconnectGrace[src][plate] > os.time() then
        grantPermanentKey(src, plate, getLicense(src), true)
    end
end)

RegisterNetEvent('shocks_vehiclekeys:server:setLockState', function(netId, state)
    local src = source
    local vehicle = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if vehicle == 0 or not validateNearbyVehicle(src, vehicle, Config.Vehicle.lockDistance) then return end
    local plate = vehiclePlate(vehicle)
    if not hasAccess(src, plate) then
        notify(src, 'You do not have the keys for this vehicle.', 'error')
        return
    end
    local lockState = tonumber(state) or 1
    Entity(vehicle).state:set('shocks_vehiclekeys_lock', lockState, true)
end)

RegisterNetEvent('shocks_vehiclekeys:server:setEngineState', function(netId, enabled)
    local src = source
    local vehicle = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if vehicle == 0 or not validateNearbyVehicle(src, vehicle, Config.Vehicle.engineDistance) then return end
    if GetPedInVehicleSeat(vehicle, -1) ~= GetPlayerPed(src) then return end
    local plate = vehiclePlate(vehicle)
    if not hasAccess(src, plate) then return end
    Entity(vehicle).state:set('shocks_vehiclekeys_engine', enabled and true or false, true)
end)

RegisterNetEvent('shocks_vehiclekeys:server:hotwireGrant', function(netId)
    local src = source
    if not Config.Access.allowHotwireGrant then return end
    local vehicle = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if vehicle == 0 or not validateNearbyVehicle(src, vehicle, Config.Vehicle.lockDistance) then return end
    local plate = vehiclePlate(vehicle)
    if not plate or hasAccess(src, plate) then return end
    grantPermanentKey(src, plate, 'hotwire', false)
end)

-- QB compatibility events.
if Config.Compatibility.registerQbEvents then
    RegisterNetEvent('qb-vehiclekeys:server:GiveVehicleKeys', function(receiver, plate)
        local src = source
        local targets = type(receiver) == 'table' and receiver or { receiver }
        plate = trim(plate)
        if not plate or findVehicleNearPlayer(src, plate, Config.Vehicle.lockDistance + 2.5) == 0 or not hasAccess(src, plate) then return end
        for _, id in pairs(targets) do
            local target = tonumber(id)
            if target and target ~= src and DoesPlayerExist(target) then
                local targetPed = GetPlayerPed(target)
                if targetPed ~= 0 and #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(targetPed)) <= 5.0 then
                    grantPermanentKey(target, plate, getLicense(src), false)
                end
            end
        end
    end)

    RegisterNetEvent('qb-vehiclekeys:server:RemoveVehicleKeys', function(plate)
        local src = source
        removePermanentKey(src, plate, false)
    end)

    RegisterNetEvent('qb-vehiclekeys:server:AcquireVehicleKeys', function(netId)
        TriggerEvent('shocks_vehiclekeys:server:acquire', netId)
    end)

    RegisterNetEvent('qb-vehiclekeys:server:setVehLockState', function(netId, state)
        TriggerEvent('shocks_vehiclekeys:server:setLockState', netId, state)
    end)
end

-- Common Qbox compatibility alias used by older custom scripts.
RegisterNetEvent('qbx_vehiclekeys:server:SetVehicleOwner', function(plate)
    local src = source
    plate = trim(plate)
    if not plate then return end
    local owner = getVehicleOwnerByPlate(plate)
    if owner and owner.citizenid == getCitizenId(src) then
        grantPermanentKey(src, plate, getLicense(src), true)
    end
end)

RegisterCommand(Config.Commands.addKeys, function(src, args)
    if src ~= 0 and not IsPlayerAceAllowed(src, Config.Admin.ace) then return end
    local target = tonumber(args[1])
    local plate = trim(args[2])
    if not target or not plate then
        if src ~= 0 then notify(src, ('Use /%s [player id] [plate].'):format(Config.Commands.addKeys), 'error') end
        return
    end
    grantPermanentKey(target, plate, getLicense(src), false)
end, false)

RegisterCommand(Config.Commands.rotateKeys, function(src, args)
    if src ~= 0 and not IsPlayerAceAllowed(src, Config.Admin.ace) then return end
    local plate = trim(table.concat(args, ' '))
    if not plate or plate == '' then return end
    MySQL.update.await(('DELETE FROM `%s` WHERE plate = ?'):format(Config.Persistence.databaseTable), { plate })
    for playerId in pairs(KeyCache) do sendKeyList(playerId) end
end, false)


if Config.Compatibility.registerQbCallbacks and Framework.name == 'qbcore' and Framework.qb then
    Framework.qb.Functions.CreateCallback('qb-vehiclekeys:server:GetVehicleKeys', function(source, cb)
        local citizenid = getCitizenId(source)
        local result = {}
        if citizenid then
            local owned = MySQL.query.await('SELECT plate FROM player_vehicles WHERE citizenid = ?', { citizenid }) or {}
            for i = 1, #owned do result[trim(owned[i].plate)] = true end
            local shared = MySQL.query.await(('SELECT plate FROM `%s` WHERE citizenid = ? AND key_type = ?'):format(Config.Persistence.databaseTable), { citizenid, 'permanent' }) or {}
            for i = 1, #shared do result[trim(shared[i].plate)] = true end
        end
        cb(result)
    end)

    Framework.qb.Functions.CreateCallback('qb-vehiclekeys:server:checkPlayerOwned', function(source, cb, plate)
        cb(isOwner(source, trim(plate)))
    end)
end

AddEventHandler('playerJoining', function()
    local src = source
    CreateThread(function()
        Wait(2500)
        if Config.Persistence.loadOnPlayerJoin then sendKeyList(src) end
    end)
end)

AddEventHandler('playerDropped', function()
    local src = source
    KeyCache[src] = nil
    TemporaryKeys[src] = nil
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= cache.resource then return end
    CreateThread(function()
        Wait(1000)
        for _, playerId in ipairs(GetPlayers()) do
            sendKeyList(tonumber(playerId))
        end
    end)
end)

CreateThread(function()
    while true do
        Wait((Config.Persistence.refreshIntervalMinutes or 5) * 60000)
        for _, playerId in ipairs(GetPlayers()) do
            sendKeyList(tonumber(playerId))
        end
    end
end)

print(('[SHOCKS Vehicle Keys] v%s started (%s).'):format(Config.Version, Framework.name))


RegisterNetEvent('shocks_vehiclekeys:server:requestOwnPlateKey', function(plate)
    local src = source
    plate = trim(plate)
    if not plate then return end
    if isOwner(src, plate) then grantPermanentKey(src, plate, getLicense(src), true) end
end)

RegisterNetEvent('shocks_vehiclekeys:server:removeLocalKey', function(plate)
    removePermanentKey(source, plate, true)
end)

RegisterNetEvent('shocks_vehiclekeys:server:giveSelfByPlate', function(plate)
    local src = source
    plate = trim(plate)
    if plate and isOwner(src, plate) then grantPermanentKey(src, plate, getLicense(src), true) end
end)
