/*
    CQ_fnc_depotSpawn  (server, from the depot menu through remoteExec)
    [_player, _class] call CQ_fnc_depotSpawn;
    Free vehicle from the global stock at the vehicle depot the player stands at (CQ_depots:
    repair station furniture + its helipad). Checks, in order:
      - at a depot (CQ_depotRange), class in the quota table (CQ_baseVehicles)
      - stock: fewer of that class out (alive) than its quota
      - who: squad leaders, and Falcon pilots (CQ_falconClass): aircraft only, CQ_falconPerPilot
        out each, no cooldown, not counted against a squad cap
      - squad leaders: fewer than CQ_depotMaxPerSquad depot vehicles out for the squad; then
        CQ_depotBurst requests in a row before the cooldown (CQ_depotCooldown by the last
        vehicle's type, keyed by UID: survives respawn/reconnect)
      - the depot's helipad is clear
    The vehicle spawns on the pad, owned by the player's group. CQ_fnc_depotTick returns it to
    the stock when destroyed or abandoned (CQ_vehAbandonDelay).
*/
params ["_p", "_cls"];
if (!isServer || { isNull _p }) exitWith {};
private _say = { params ["_t"]; [_t] remoteExec ["hint", _p] };
private _di = CQ_depots findIf { _p distance (_x select 0) <= CQ_depotRange + 4 };
if (_di < 0) exitWith { ["Go to a vehicle depot"] call _say };
private _qi = CQ_baseVehicles findIf { (_x select 0) == _cls };
if (_qi < 0) exitWith {};
private _quota = (CQ_baseVehicles select _qi) param [2, 1];
private _name = getText (configFile >> "CfgVehicles" >> _cls >> "displayName");
CQ_depotVehs = CQ_depotVehs select { alive _x };
if (({ typeOf _x == _cls } count CQ_depotVehs) >= _quota) exitWith { [format ["No %1 left in stock (%2 out)", _name, _quota]] call _say };
private _g = group _p;
private _uid = getPlayerUID _p;
// who may take: Falcon pilots (aircraft only, 1 out each, no cooldown) and squad leaders
private _pilot = (_p getVariable ["CQ_class", ""]) == CQ_falconClass;
private _sl = leader _g == _p && { !(_g getVariable ["CQ_solo", false]) };
if (!_pilot && { !_sl }) exitWith { ["Only squad leaders and Falcon pilots can take depot vehicles"] call _say };
if (_pilot) then {
    if !(_cls isKindOf "Air") exitWith { ["Falcon pilots take aircraft only"] call _say; _cls = "" };
    if (({ (_x getVariable ["CQ_depotOwner", ""]) == _uid } count CQ_depotVehs) >= CQ_falconPerPilot) exitWith {
        [format ["You already have %1 aircraft out. Return it at a depot first.", CQ_falconPerPilot]] call _say; _cls = "";
    };
} else {
    if (({ (_x getVariable ["CQ_depotGroup", grpNull]) == _g } count CQ_depotVehs) >= CQ_depotMaxPerSquad) exitWith {
        [format ["Your squad already has %1 depot vehicles out. Return one at a depot first.", CQ_depotMaxPerSquad]] call _say; _cls = "";
    };
    private _left = (CQ_depotReady getOrDefault [_uid, 0]) - serverTime;
    if (_left > 0) exitWith { [format ["Next vehicle request in %1", [_left, "MM:SS"] call BIS_fnc_secondsToString]] call _say; _cls = "" };
};
if (_cls == "") exitWith {};
(CQ_depots select _di) params ["", "_pad", "_padDir"];
if (((nearestObjects [_pad, ["LandVehicle", "Air"], 9]) select { alive _x }) isNotEqualTo []) exitWith { ["The depot pad is blocked: move the vehicle off the pad"] call _say };

private _v = createVehicle [_cls, _pad, [], 0, "NONE"];
_v setDir _padDir;
_v allowDamage false;            // no damage while it settles on the pad
[_v] spawn { params ["_v"]; sleep 10; if (alive _v) then { _v setDamage 0; _v allowDamage true } };
clearWeaponCargoGlobal _v; clearMagazineCargoGlobal _v; clearItemCargoGlobal _v; clearBackpackCargoGlobal _v;
_v addItemCargoGlobal ["FirstAidKit", 4];
_v setVariable ["CQ_depotGroup", _g, true];
_v setVariable ["CQ_depotOwner", _uid, true];
// who destroyed it (MPKilled fires on every machine, also when a player drives it): logged by CQ_fnc_depotTick
_v addMPEventHandler ["MPKilled", {
    params ["_v", "_k", "_i"];
    if (!isServer) exitWith {};
    private _who = if (isNull _i) then { _k } else { _i };
    _v setVariable ["CQ_killedBy", if (isNull _who || { _who == _v }) then { "crash or unknown" } else {
        format ["%1 (%2, %3)", [name _who, typeOf _who] select (_who isKindOf "AllVehicles" && { !(_who isKindOf "CAManBase") }), typeOf vehicle _who, side group _who] }];
}];
CQ_depotVehs pushBack _v;
publicVariable "CQ_depotVehs";

// squad leaders: CQ_depotBurst vehicles in a row, then the cooldown of the last one's type
if (!_pilot) then {
    if (isNil "CQ_depotTaken") then { CQ_depotTaken = createHashMap };
    private _n = (CQ_depotTaken getOrDefault [_uid, 0]) + 1;
    if (_n >= CQ_depotBurst) then {
        private _cat = [["light", "truck"] select (_cls isKindOf "Truck_F"), "air"] select (_cls isKindOf "Air");
        private _cd = (CQ_depotCooldown select (CQ_depotCooldown findIf { (_x select 0) == _cat })) select 1;
        CQ_depotReady set [_uid, serverTime + _cd];
        publicVariable "CQ_depotReady";
        _n = 0;
    };
    CQ_depotTaken set [_uid, _n];
};
[format ["%1 ready on the depot pad.", _name]] call _say;
["Depot: %1 (%2) took a %3, %4 left", [name _p, groupId _g, _cls, _quota - ({ typeOf _x == _cls } count CQ_depotVehs)]] call CQ_fnc_log;
