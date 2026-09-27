Config = {}

Config.Version = '1.1.0'
Config.Debug = false

Config.Framework = 'auto' -- auto | qbox | qbcore
Config.QBCoreResource = 'qb-core'
Config.QboxResource = 'qbx_core'

Config.Persistence = {
    databaseTable = 'shocks_vehicle_keys',
    loadOnPlayerJoin = true,
    refreshIntervalMinutes = 5,
    reconnectKeyGraceSeconds = 120,
}

Config.Access = {
    ownerHasKeys = true,
    permanentSharedKeys = true,
    temporaryKeys = true,
    allowHotwireGrant = true,
}

Config.Controls = {
    lock = 'L',
    engine = 'G',
    lockCommand = 'shocks_lockvehicle',
    engineCommand = 'shocks_toggleengine',
}

Config.Vehicle = {
    lockOnSpawn = 2,
    autoAcquireOnEnterRunning = false,
    autoLockWhenLeaving = false,
    leaveEngineRunning = false,
    defaultWorldVehicleLocked = false,
    preventEngineStartWithoutKeys = true,
    requireDriverForEngineToggle = true,
    lockDistance = 7.5,
    engineDistance = 5.0,
}

Config.Animation = {
    enabled = true,
    dictionary = 'anim@mp_player_intmenu@key_fob@',
    clip = 'fob_click',
    duration = 650,
}

Config.Audio = {
    enabled = true,
    soundName = 'Remote_Control_Fob',
    soundSet = 'PI_Menu_Sounds',
}

Config.Notifications = {
    enabled = true,
}

Config.Commands = {
    giveKeys = 'givekeys',
    removeKeys = 'removekeys',
    addKeys = 'addkeys',
    rotateKeys = 'rotatekeys',
}

Config.Admin = {
    ace = 'shocks.vehiclekeys.admin',
    qbPermissions = { admin = true, god = true },
}

Config.Compatibility = {
    registerQbEvents = true,
    registerQbCallbacks = true,
    qbxAliases = true,
    provideQbVehiclekeysAlias = true,
    provideQbxVehiclekeysAlias = true,
}

Config.Integrations = {
    hotwire = {
        enabled = true,
        resource = 'shocks_hotwire',
        autoStartOnKeylessVehicle = false,
        exposeBridgeExport = true,
    },
    garage = {
        enabled = true,
        resource = 'shocks_garage',
        refreshOnGarageSpawn = true,
    },
}

Config.Bridge = {
    allowGarageToGrantSpawnKeys = true,
    allowHotwireToGrantPermanentKeys = true,
    validateProviderCallbacks = true,
}

Config.WorldVehicles = {
    enabled = true,
    randomInitialLock = false,
    lockedStates = { 1, 2 },
}

Config.VehicleRules = {
    ignoredClasses = { [13] = true },
    alwaysUnlockOwned = true,
    ownerGetsPermanentKey = true,
    removeKeysOnVehicleDelete = true,
}
