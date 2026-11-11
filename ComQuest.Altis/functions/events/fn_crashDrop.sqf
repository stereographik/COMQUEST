/*
    CQ_fnc_crashDrop  (server)
    [] call CQ_fnc_crashDrop;
    The crash countdown ran out (CQ_fnc_crashTick) or the debug panel skipped it: the carrier
    paradrops one of CQ_crashDropClasses (DLC ones skipped) with CQ_crashDropSquad in its cargo
    seats near the wreck; once down it roams around the site (CQ_fnc_crashRoam).
*/
if (!isServer || { isNil "CQ_crashState" }) exitWith {};
private _s = CQ_crashState;
if ((_s get "dropped") || { _s get "secured" }) exitWith {};
_s set ["dropped", true];
CQ_crashAlarm = false; publicVariable "CQ_crashAlarm";
private _ok = CQ_crashDropClasses select { isClass (configFile >> "CfgVehicles" >> _x) && { getText (configFile >> "CfgVehicles" >> _x >> "DLC") == "" } };
if (_ok isEqualTo []) exitWith { ["Crash event: no drop vehicle available (all DLC?)"] call CQ_fnc_log };
private _cls = selectRandom _ok;
private _site = _s get "pos";
["Crash event: time is up, the carrier drops a %1 on the wreck (from %2)", [_cls, _ok]] call CQ_fnc_log;
["crashDrop", []] call CQ_fnc_say;
CQ_crashDropSite = _site;
[_cls, _site getPos [120, random 360], {
    params ["_v"];
    [_v] call CQ_fnc_crewVehicle;
    [_v, CQ_vehSpawnAmmo] call CQ_fnc_vehAmmoInit;
    private _g = group effectiveCommander _v;
    {
        if ((_v emptyPositions "cargo") < 1) exitWith {};
        private _u = _g createUnit [_x, getPosATL _v, [], 5, "NONE"];
        [[_u]] call CQ_fnc_unitPrep;
        _u moveInCargo _v;
    } forEach CQ_crashDropSquad;
    _g setBehaviour "AWARE";
    _g setCombatMode "RED";
    _g enableDynamicSimulation false;
    ["Crash event: %1 down at %2 with %3 men", [typeOf _v, mapGridPosition _v, count units _g]] call CQ_fnc_log;
    [_v, CQ_crashDropSite] spawn CQ_fnc_crashRoam;
}, "Crash"] spawn CQ_fnc_paraDropVehicle;
