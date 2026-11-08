/*
    CQ_fnc_crateCargo  (server, from a player action through remoteExec)
    ["load", _crate, _player] / ["unload", _vehicle, _player]
    Supply crates ride in any vehicle, up to its slots (CQ_fnc_crateSlots): loading stores the
    crate's contents on the vehicle and removes the crate; unloading puts a crate with the
    same contents on the ground behind the vehicle. A destroyed vehicle loses its cargo.
*/
params ["_mode", "_obj", "_who"];
if (!isServer) exitWith {};
private _say = { params ["_t"]; [_t] remoteExec ["hint", owner _who] };

if (_mode == "load") then {
    private _crate = _obj;
    if (!alive _crate || { !(_crate getVariable ["CQ_crate", false]) }) exitWith {};
    private _vehs = (nearestObjects [_crate, ["Car", "Tank", "Helicopter", "Ship", "Plane"], 12]) select { alive _x && { _x getVariable ["CQ_team", ""] == "" } };
    if (_vehs isEqualTo []) exitWith { ["No vehicle close enough (12 m)"] call _say };
    private _v = _vehs select 0;
    private _cargo = _v getVariable ["CQ_crates", []];
    private _slots = [_v] call CQ_fnc_crateSlots;
    if (count _cargo >= _slots) exitWith { [format ["%1 is full (%2/%2 crates)", getText (configOf _v >> "displayName"), _slots]] call _say };
    _cargo pushBack [getMagazineCargo _crate, getItemCargo _crate, getWeaponCargo _crate, getBackpackCargo _crate];
    _v setVariable ["CQ_crates", _cargo, true];
    deleteVehicle _crate;
    [format ["Crate loaded into %1 (%2/%3)", getText (configOf _v >> "displayName"), count _cargo, _slots]] call _say;
};

if (_mode == "unload") then {
    private _v = _obj;
    private _cargo = _v getVariable ["CQ_crates", []];
    if (!alive _v || { _cargo isEqualTo [] }) exitWith {};
    private _cnt = _cargo deleteAt (count _cargo - 1);
    _v setVariable ["CQ_crates", _cargo, true];
    private _want = _v getPos [((boundingBoxReal _v) select 2) * 0.6 + 2, (getDir _v) + 180];
    private _p = [_want, 1, 8] call CQ_fnc_clearPos;
    if (_p isEqualTo []) then { _p = _want };
    private _c = createVehicle [CQ_crateClass, _p, [], 0, "NONE"];
    clearWeaponCargoGlobal _c; clearMagazineCargoGlobal _c; clearItemCargoGlobal _c; clearBackpackCargoGlobal _c;
    _cnt params ["_m", "_i", "_w", "_b"];
    { _c addMagazineCargoGlobal [_x, (_m select 1) select _forEachIndex] } forEach (_m select 0);
    { _c addItemCargoGlobal [_x, (_i select 1) select _forEachIndex] } forEach (_i select 0);
    { _c addWeaponCargoGlobal [_x, (_w select 1) select _forEachIndex] } forEach (_w select 0);
    { _c addBackpackCargoGlobal [_x, (_b select 1) select _forEachIndex] } forEach (_b select 0);
    _c setVariable ["CQ_crate", true, true];
    ["Crate unloaded"] call _say;
};
