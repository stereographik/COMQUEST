/*
    CQ_fnc_tigrisTick  (server, director task, every 4 s)
    Tigris radar: every MAGPIE drone within CQ_tigrisRadar of a Tigris, with a clear line of
    sight, is handed to its crew as a fully known target and engaged (radar forced on, gunner
    ordered to fire). The game AI often ignores a small drone flying high, so inside
    CQ_tigrisMissileRange the Tigris also launches a Titan at it every CQ_tigrisSalvo s, guided
    onto the drone (setMissileTarget): entering that range is deadly. Out of missiles, it
    reloads after 60 s.
*/
if (time < (missionNamespace getVariable ["CQ_tigrisNext", 0])) exitWith {};
CQ_tigrisNext = time + 4;
CQ_tigrises = (missionNamespace getVariable ["CQ_tigrises", []]) select { alive _x };
if (CQ_tigrises isEqualTo []) exitWith {};
private _drones = (missionNamespace getVariable ["CQ_magVehs", []]) select { alive _x && { ((getPosATL _x) select 2) > 20 } };
if (_drones isEqualTo []) exitWith {};
{
    private _t = _x;
    private _gun = gunner _t;
    if (!alive _gun || { side group _gun != east }) then { continue };
    _t setVehicleRadar 1;
    private _eye = (getPosASL _t) vectorAdd [0, 0, 3];
    private _tgts = _drones select {
        _x distance _t < CQ_tigrisRadar && { !(terrainIntersectASL [_eye, getPosASL _x]) }
    };
    if (_tgts isEqualTo []) then { continue };
    private _g = group _gun;
    { _g reveal [_x, 4] } forEach _tgts;
    private _tgt = ([_tgts, [], { _x distance _t }, "ASCEND"] call BIS_fnc_sortBy) select 0;
    _g setCombatMode "RED";
    _gun doTarget _tgt;
    _gun doFire _tgt;
    // the game AI rarely launches at a small drone high up: inside missile range, with a clear
    // line of sight, the Tigris fires a Titan at it every CQ_tigrisSalvo s, guided onto it
    if (_tgt distance _t < CQ_tigrisMissileRange && { time >= (_t getVariable ["CQ_salvoT", 0]) }) then {
        private _mw = _t getVariable ["CQ_missileWpn", ""];
        if (_mw == "") then {
            _mw = ((_t weaponsTurret [0]) select {
                private _mags = getArray (configFile >> "CfgWeapons" >> _x >> "magazines");
                _mags isNotEqualTo [] && { (getText (configFile >> "CfgAmmo" >> getText (configFile >> "CfgMagazines" >> (_mags select 0) >> "ammo") >> "simulation")) == "shotMissile" }
            }) param [0, "-"];
            _t setVariable ["CQ_missileWpn", _mw];
            _t addEventHandler ["Fired", {
                params ["_t", "", "", "", "", "", "_p"];
                private _tg = _t getVariable ["CQ_missileTgt", objNull];
                if (!isNull _p && { alive _tg } && { _p isKindOf "MissileCore" }) then { _p setMissileTarget [_tg, true] };
            }];
        };
        if (_mw == "-") exitWith {};
        private _wm = (getArray (configFile >> "CfgWeapons" >> _mw >> "magazines")) apply { toLower _x };
        if (((magazinesAllTurrets _t) findIf { (toLower (_x select 0)) in _wm && { (_x select 2) > 0 } }) == -1) then {
            _t setVehicleAmmo 1;                     // reloaded from its own stock
            _t setVariable ["CQ_salvoT", time + 60];
        } else {
            _t setVariable ["CQ_missileTgt", _tgt];
            _t selectWeaponTurret [_mw, [0]];
            if (_t fireAtTarget [_tgt, _mw]) then {
                _t setVariable ["CQ_salvoT", time + CQ_tigrisSalvo];
                ["Tigris at %1 fires a missile at MAGPIE %2 (%3 m)", [mapGridPosition _t, _tgt getVariable ["CQ_magName", typeOf _tgt], round (_tgt distance _t)]] call CQ_fnc_log;
            };
        };
    };
    if (time - (_t getVariable ["CQ_lockLogT", -1e6]) > 30) then {
        _t setVariable ["CQ_lockLogT", time];
        ["Tigris at %1 locked MAGPIE %2 (%3 m)", [mapGridPosition _t, _tgt getVariable ["CQ_magName", typeOf _tgt], round (_tgt distance _t)]] call CQ_fnc_log;
    };
} forEach CQ_tigrises;
