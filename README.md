# SHOCKS Vehicle Keys 1.0.0

Standalone QBCore/Qbox vehicle key system intended to replace `qbx_vehiclekeys` / `qb-vehiclekeys`. Uses `ox_lib` and `oxmysql`. No ESX support.

## Features

- Persistent permanent shared keys in `shocks_vehicle_keys`.
- Vehicle owners are recognised from `player_vehicles`.
- Temporary runtime key access.
- `L` lock/unlock and `G` engine toggle (both configurable).
- Lock/engine state replicated with entity state bags.
- Key-fob animation and sound (both configurable).
- Key sharing with server-side proximity validation.
- Qbox exports: `HasKeys`, `GiveKeys`, `RemoveKeys`, `SetLockState`.
- Additional `GrantKeys` export for trusted resources such as SHOCKS Hotwire.
- QB compatibility events: `vehiclekeys:client:SetOwner`, `qb-vehiclekeys:client:AddKeys`, `qb-vehiclekeys:client:RemoveKeys`, plus common server events/callbacks.
- FiveM manifest `provide 'qbx_vehiclekeys'` and `provide 'qb-vehiclekeys'` so the resource can stand in for those names when another resource requires them. FiveM documents `provide` specifically as a replacement-resource mechanism.

## Install

1. Put the folder in your resources directory as `shocks_vehiclekeys`.
2. Import `sql/install.sql`.
3. Remove/stop the original `qbx_vehiclekeys` resource. Do not run both key systems at once.
4. Start SHOCKS Vehicle Keys before resources that call its exports.

```cfg
ensure ox_lib
ensure oxmysql
ensure qbx_core # or qb-core
ensure shocks_vehiclekeys
```

The current Qbox core server config calls `qbx_vehiclekeys:GiveKeys` and `SetLockState`, while current Qbox docs list server `HasKeys`, `GiveKeys`, and `RemoveKeys`; SHOCKS implements those contracts and translates Qbox's `lock`/`unlock` strings to GTA lock states.

## Main exports

Client:

```lua
exports.shocks_vehiclekeys:HasKeys(vehicle)
exports.shocks_vehiclekeys:GiveKeys(vehicle)
exports.shocks_vehiclekeys:RemoveKeys(vehicle)
exports.shocks_vehiclekeys:SetLockState(vehicle, 2)
exports.shocks_vehiclekeys:SetEngineState(vehicle, true)
```

Server:

```lua
exports.shocks_vehiclekeys:GiveKeys(source, vehicle, true)
exports.shocks_vehiclekeys:GrantKeys(source, vehicle, true) -- trusted/forced grant
exports.shocks_vehiclekeys:RemoveKeys(source, vehicle, true)
exports.shocks_vehiclekeys:HasKeys(source, vehicle)
exports.shocks_vehiclekeys:SetLockState(vehicle, 'lock')
```

## Commands

`/givekeys [id]` shares the current vehicle's keys with a nearby player. Admins can use `/addkeys [id] [plate]` and `/rotatekeys [plate]`.

## SHOCKS Bridges (V1.1)

The key system has an explicit client bridge at `bridge/client/hotwire.lua`.

```lua
Config.Integrations.hotwire = {
    enabled = true,
    resource = 'shocks_hotwire',
    autoStartOnKeylessVehicle = false,
}
```

Set `autoStartOnKeylessVehicle = true` only when SHOCKS Hotwire should be started by the key system. Leave it false when Hotwire's own `AutoStart` owns that behaviour.

## Recommended order

```cfg
ensure shocks_vehiclekeys
ensure shocks_hotwire
ensure shocks_garage
```

SHOCKS Keys is optional. If the garage/hotwire configs use `provider = 'qbx'`, this resource can remain stopped.
