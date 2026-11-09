/*
    CQ_fnc_statsInit  (server, once)
    Kill / death / team-kill / vehicle-kill tracking for the player statistics:
      enemy soldier killed by a player     killsInf (+ longest kill distance)
      enemy vehicle destroyed by a player  vehLight (cars, trucks, MRAPs) / vehArmor (APCs,
                                           tanks) / vehAir / vehStatic (static weapons)
      player killed                        deaths
      friendly soldier killed by a player  teamkills
*/
if (!isServer) exitWith {};
CQ_stats = createHashMap;
CQ_statsDirty = true;
CQ_statsNext = 0;
addMissionEventHandler ["EntityKilled", {
    params ["_unit", "_killer", "_inst"];
    if (isNull _inst) then { _inst = effectiveCommander _killer };
    if (isNull _inst && { !isNull _killer }) then { _inst = _killer };
    private _side = side group _unit;
    if (!(_unit isKindOf "CAManBase") && { !(_side in [east, west, resistance]) }) then {
        _side = [east, west, resistance, civilian] param [getNumber (configOf _unit >> "side"), civilian];
    };
    if (isPlayer _unit) then { [_unit, [["deaths", 1]]] call CQ_fnc_statsAdd };
    if (isNull _inst || { !isPlayer _inst } || { _inst == _unit }) exitWith {};
    if (_unit isKindOf "CAManBase") then {
        if (_side == west) then {
            [_inst, [["teamkills", 1]]] call CQ_fnc_statsAdd;
        } else {
            if (_side in [east, resistance]) then {
                [_inst, [["killsInf", 1], ["longest", round (_inst distance _unit)]]] call CQ_fnc_statsAdd;
            };
        };
    } else {
        if !(_side in [east, resistance]) exitWith {};
        private _k = switch (true) do {
            case (_unit isKindOf "Air"): { "vehAir" };
            case (_unit isKindOf "StaticWeapon"): { "vehStatic" };
            case (_unit isKindOf "Tank" || { _unit isKindOf "Wheeled_APC_F" }): { "vehArmor" };
            case (_unit isKindOf "LandVehicle" || { _unit isKindOf "Ship" }): { "vehLight" };
            default { "" };
        };
        if (_k != "") then { [_inst, [[_k, 1]]] call CQ_fnc_statsAdd };
    };
}];
["Player statistics: tracking on"] call CQ_fnc_log;
