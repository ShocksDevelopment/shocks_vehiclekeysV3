SHOCKSKeysHotwireBridge = SHOCKSKeysHotwireBridge or {}

function SHOCKSKeysHotwireBridge.Resolve()
    local cfg = Config.Integrations and Config.Integrations.hotwire
    if type(cfg) ~= 'table' then return nil end
    if cfg.enabled == false or cfg.provider == 'off' or cfg.provider == 'none' then return nil end

    local resource = cfg.resource or 'shocks_hotwire'
    if GetResourceState(resource) == 'started' then return resource end
    return nil
end

function SHOCKSKeysHotwireBridge.Start(vehicle)
    local resource = SHOCKSKeysHotwireBridge.Resolve()
    if not resource then return false end
    local ok, result = pcall(function() return exports[resource]:StartHotwire(vehicle) end)
    return ok and result == true
end

function SHOCKSKeysHotwireBridge.IsActive()
    local resource = SHOCKSKeysHotwireBridge.Resolve()
    if not resource then return false end
    local ok, result = pcall(function() return exports[resource]:IsActive() end)
    return ok and result == true
end
