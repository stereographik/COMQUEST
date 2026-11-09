/*
    CQ_fnc_shopBuy  (server, from the shop menu through remoteExec)
    [_player, _class] call CQ_fnc_shopBuy;
    The squad leader buys an armed vehicle with his SQUAD's combat points (group variable
    CQ_sqPts, earned in CQ_fnc_statsAdd). Checks: leader of a real squad, at the terminal,
    enough points, fewer than CQ_shopMaxPerSquad bought vehicles alive, LZ clear.
    The vehicle spawns on the shop LZ, does not respawn, and is owned by the squad.
*/
params ["_p", "_cls"];
if (!isServer || { isNull _p }) exitWith {};
private _say = { params ["_t"]; [_t] remoteExec ["hint", _p] };
private _g = group _p;
if (_g getVariable ["CQ_solo", false] || { leader _g != _p }) exitWith { ["Only a squad leader can buy vehicles"] call _say };
if (isNil "CQ_shopTerminal" || { _p distance CQ_shopTerminal > CQ_shopRange + 4 }) exitWith { ["Go to the shop terminal"] call _say };
private _i = CQ_shopCatalog findIf { (_x select 0) == _cls };
if (_i < 0) exitWith {};
(CQ_shopCatalog select _i) params ["", "_cost", "_name"];
private _pts = _g getVariable ["CQ_sqPts", 0];
if (_pts < _cost) exitWith { [format ["Not enough squad points (%1 / %2)", _pts, _cost]] call _say };
private _owned = (_g getVariable ["CQ_sqBought", []]) select { alive _x };
if (count _owned >= CQ_shopMaxPerSquad) exitWith { [format ["Your squad already has a bought vehicle (%1)", getText (configOf (_owned select 0) >> "displayName")]] call _say };
if (((nearestObjects [CQ_shopLZ, ["LandVehicle", "Air"], 9]) select { alive _x }) isNotEqualTo []) exitWith { ["The shop LZ is blocked: move the vehicle off the pad"] call _say };

private _v = createVehicle [_cls, CQ_shopLZ, [], 0, "NONE"];
_v setDir CQ_shopDir;
_v allowDamage false;
[_v] spawn { params ["_v"]; sleep 8; if (alive _v) then { _v allowDamage true } };
clearWeaponCargoGlobal _v; clearMagazineCargoGlobal _v; clearItemCargoGlobal _v; clearBackpackCargoGlobal _v;
_v addItemCargoGlobal ["FirstAidKit", 4];
_v setVariable ["CQ_boughtBy", groupId _g, true];
_g setVariable ["CQ_sqPts", _pts - _cost, true];
_g setVariable ["CQ_sqBought", _owned + [_v], true];
private _msg = format ["%1 bought a %2 for the squad (%3 points left)", name _p, _name, _pts - _cost];
[_msg] remoteExec ["systemChat", units _g select { isPlayer _x }];
["Shop: %1 (%2) bought %3 for %4 points", [name _p, groupId _g, _cls, _cost]] call CQ_fnc_log;
