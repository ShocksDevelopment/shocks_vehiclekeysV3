local keys = {}
local lastToggle = 0
local lastEngineToggle = 0
local keysReady = false

local function trim(value)
    if not value then return nil end
    return tostring(value):gsub('^%s*(.-)%s*$', '%1')
end

local function plateOf(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return nil end
    return trim(GetVehicleNumberPlateText(vehicle))
end

local function hasKeys(vehicle)
    local plate = plateOf(vehicle)
    return plate and keys[plate] == true or false
end

local function notify(msg, kind)
    lib.notify({ description = msg, type = kind or 'inform' })
end

exports('HasKeys', hasKeys)
exports('GetKeys', function()
    return keys
end)
exports('GiveKeys', function(vehicle, skipServerNotify)
    if not vehicle or vehicle == 0 then return false end
    TriggerServerEvent('shocks_vehiclekeys:server:acquire', NetworkGetNetworkIdFromEntity(vehicle))
    return true
end)
exports('RemoveKeys', function(vehicle)
    if not vehicle or vehicle == 0 then return false end
    local plate = plateOf(vehicle)
    if not plate then return false end
    TriggerServerEvent('shocks_vehiclekeys:server:removeLocalKey', plate)
    return true
end)
exports('GiveKeysByPlate', function(plate)
    if not plate then return false end
    TriggerServerEvent('shocks_vehiclekeys:server:giveSelfByPlate', trim(plate))
    return true
end)
exports('SetLockState', function(vehicle, state)
    if not vehicle or vehicle == 0 then return false end
    local value = (state == 'lock' or state == 'locked') and 2 or ((state == 'unlock' or state == 'unlocked') and 1 or (tonumber(state) or 1))
    SetVehicleDoorsLocked(vehicle, value)
    if not hasKeys(vehicle) then return false end
    TriggerServerEvent('shocks_vehiclekeys:server:setLockState', NetworkGetNetworkIdFromEntity(vehicle), value)
    return true
end)
exports('SetEngineState', function(vehicle, enabled)
    if not vehicle or vehicle == 0 then return false end
    if not hasKeys(vehicle) then return false end
    SetVehicleEngineOn(vehicle, enabled and true or false, false, true)
    TriggerServerEvent('shocks_vehiclekeys:server:setEngineState', NetworkGetNetworkIdFromEntity(vehicle), enabled and true or false)
    return true
end)

function GetKeysForVehicle(vehicle)
    return hasKeys(vehicle)
end
exports('GetKeysForVehicle', GetKeysForVehicle)

RegisterNetEvent('shocks_vehiclekeys:client:syncKeys', function(serverKeys)
    keys = type(serverKeys) == 'table' and serverKeys or {}
    keysReady = true
    LocalPlayer.state:set('keysList', keys, false)
end)

RegisterNetEvent('shocks_vehiclekeys:client:notify', function(msg, kind)
    notify(msg, kind)
end)

AddStateBagChangeHandler('shocks_vehiclekeys_lock', nil, function(bagName, key, value)
    local entity = GetEntityFromStateBagName(bagName)
    if entity == 0 or not DoesEntityExist(entity) then return end
    if value ~= nil then SetVehicleDoorsLocked(entity, tonumber(value) or 1) end
end)

AddStateBagChangeHandler('shocks_vehiclekeys_engine', nil, function(bagName, key, value)
    local entity = GetEntityFromStateBagName(bagName)
    if entity == 0 or not DoesEntityExist(entity) then return end
    SetVehicleEngineOn(entity, value == true, true, true)
end)

local function playFob()
    if not Config.Animation.enabled then return end
    local dict = Config.Animation.dictionary
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do Wait(0) end
    if HasAnimDictLoaded(dict) then
        TaskPlayAnim(cache.ped, dict, Config.Animation.clip, 8.0, 8.0, Config.Animation.duration, 49, 0.0, false, false, false)
        SetTimeout(Config.Animation.duration, function() StopAnimTask(cache.ped, dict, Config.Animation.clip, 1.0) end)
    end
end

local function playSound()
    if Config.Audio.enabled then
        PlaySoundFrontend(-1, Config.Audio.soundName, Config.Audio.soundSet, true)
    end
end

local function getControlledVehicle()
    local vehicle = GetVehiclePedIsIn(cache.ped, false)
    if vehicle ~= 0 then return vehicle end
    local coords = GetEntityCoords(cache.ped)
    local pool = GetGamePool('CVehicle')
    local best, bestDistance
    for i = 1, #pool do
        local candidate = pool[i]
        if DoesEntityExist(candidate) then
            local distance = #(coords - GetEntityCoords(candidate))
            if distance <= Config.Vehicle.lockDistance and (not bestDistance or distance < bestDistance) then
                best, bestDistance = candidate, distance
            end
        end
    end
    return best or 0
end

local function toggleLock()
    if GetGameTimer() - lastToggle < 650 then return end
    lastToggle = GetGameTimer()
    local vehicle = getControlledVehicle()
    if vehicle == 0 or not hasKeys(vehicle) then
        notify('You do not have the keys for this vehicle.', 'error')
        return
    end
    local state = GetVehicleDoorLockStatus(vehicle)
    local nextState = (state == 2 or state == 10) and 1 or 2
    playFob()
    playSound()
    SetVehicleDoorsLocked(vehicle, nextState)
    TriggerServerEvent('shocks_vehiclekeys:server:setLockState', NetworkGetNetworkIdFromEntity(vehicle), nextState)
end

local function toggleEngine()
    if GetGameTimer() - lastEngineToggle < 500 then return end
    lastEngineToggle = GetGameTimer()
    local vehicle = GetVehiclePedIsIn(cache.ped, false)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= cache.ped then return end
    if not hasKeys(vehicle) then
        notify('You do not have the keys for this vehicle.', 'error')
        return
    end
    local enabled = not GetIsVehicleEngineRunning(vehicle)
    SetVehicleEngineOn(vehicle, enabled, false, true)
    TriggerServerEvent('shocks_vehiclekeys:server:setEngineState', NetworkGetNetworkIdFromEntity(vehicle), enabled)
end

RegisterCommand(Config.Controls.lockCommand, toggleLock, false)
RegisterKeyMapping(Config.Controls.lockCommand, 'SHOCKS: Lock / Unlock Vehicle', 'keyboard', Config.Controls.lock)
RegisterCommand(Config.Controls.engineCommand, toggleEngine, false)
RegisterKeyMapping(Config.Controls.engineCommand, 'SHOCKS: Toggle Engine', 'keyboard', Config.Controls.engine)

RegisterCommand(Config.Commands.giveKeys, function(_, args)
    local target = tonumber(args[1])
    if not target then
        notify('Use /givekeys [id] while near or inside your vehicle.', 'error')
        return
    end
    local vehicle = GetVehiclePedIsIn(cache.ped, false)
    if vehicle == 0 then
        notify('You must be in the vehicle you want to share.', 'error')
        return
    end
    local plate = plateOf(vehicle)
    if not plate or not hasKeys(vehicle) then
        notify('You do not have the keys for this vehicle.', 'error')
        return
    end
    TriggerServerEvent('shocks_vehiclekeys:server:giveKeys', target, plate, true)
end, false)

RegisterNetEvent('vehiclekeys:client:SetOwner', function(plate)
    plate = trim(plate)
    if not plate then return end
    TriggerServerEvent('shocks_vehiclekeys:server:requestOwnPlateKey', plate)
end)

RegisterNetEvent('qb-vehiclekeys:client:AddKeys', function(plate)
    plate = trim(plate)
    if not plate then return end
    TriggerServerEvent('shocks_vehiclekeys:server:requestOwnPlateKey', plate)
end)

RegisterNetEvent('qb-vehiclekeys:client:RemoveKeys', function(plate)
    plate = trim(plate)
    if not plate then return end
    TriggerServerEvent('shocks_vehiclekeys:server:removeLocalKey', plate)
end)

RegisterNetEvent('vehiclekeys:client:RemoveKeys', function(plate)
    TriggerServerEvent('shocks_vehiclekeys:server:removeLocalKey', trim(plate))
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    keysReady = false
    TriggerServerEvent('shocks_vehiclekeys:server:requestSync')
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function()
    TriggerServerEvent('shocks_vehiclekeys:server:requestSync')
end)

RegisterNetEvent('Qbox:Client:OnPlayerLoaded', function()
    keysReady = false
    TriggerServerEvent('shocks_vehiclekeys:server:requestSync')
end)

CreateThread(function()
    Wait(3500)
    TriggerServerEvent('shocks_vehiclekeys:server:requestSync')
    while true do
        Wait(750)
        local vehicle = GetVehiclePedIsIn(cache.ped, false)
        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == cache.ped then
            local has = hasKeys(vehicle)
            if Config.Vehicle.preventEngineStartWithoutKeys and not has and GetIsVehicleEngineRunning(vehicle) then
                if not Config.Vehicle.autoAcquireOnEnterRunning then
                    SetVehicleEngineOn(vehicle, false, false, true)
                    SetVehicleUndriveable(vehicle, true)
                    SetVehicleNeedsToBeHotwired(vehicle, true)
                    if Config.Integrations.hotwire.enabled and Config.Integrations.hotwire.autoStartOnKeylessVehicle and not SHOCKSKeysHotwireBridge.IsActive() then
                        SHOCKSKeysHotwireBridge.Start(vehicle)
                    end
                end
            elseif has then
                SetVehicleUndriveable(vehicle, false)
                SetVehicleNeedsToBeHotwired(vehicle, false)
            end
        end
        ::continue::
    end
end)

RegisterNetEvent('shocks_vehiclekeys:client:applyKeyGrant', function(plate)
    plate = trim(plate)
    if plate then
        keys[plate] = true
    end
end)

exports('GetHotwireProvider', function()
    local resource = SHOCKSKeysHotwireBridge.Resolve()
    return resource or 'None'
end)
