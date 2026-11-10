/*
    CQ_fnc_tigrisTick  (server, director task, every 4 s)
    Tigris radar. A MAGPIE drone within CQ_tigrisRadar, in line of sight, is only noticed with
    a chance per check (CQ_tigrisSpot, lower far away and for the small Darter); once noticed it
    is tracked CQ_tigrisTrack s, handed to the crew and engaged. Inside CQ_tigrisMissileRange
    the Tigris launches a Titan every CQ_tigrisSalvo s; a CQ_tigrisGuide share of them is forced
    onto the drone (setMissileTarget), the rest fly on their own lock and often miss. Out of
    missiles, it reloads after 60 s.
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
    private _eye = (getPosASL _t) vectorAdd [0, 0, 3];
    private _tgts = _drones select {
        _x distance _t < CQ_tigrisRadar && { !(terrainIntersectASL [_eye, getPosASL _x]) }
    };
    if (_tgts isEqualTo []) then { _t setVehicleRadar 2; continue };
    // spotting: each check, a drone in line of sight is noticed only with a chance that falls
    // with range (CQ_tigrisSpot near -> 0 at the radar edge, x CQ_tigrisSpotSize for the small
    // Darter). Once noticed it stays tracked for CQ_tigrisTrack s while still in sight.
    private _trk = _t getVariable ["CQ_trk", createHashMap];
    {
        private _d = _x;
        if (time < (_trk getOrDefault [hashValue _d, -1])) then { continue };
        private _p = (CQ_tigrisSpot select 0) + ((CQ_tigrisSpot select 1) - (CQ_tigrisSpot select 0)) * ((_d distance _t) / CQ_tigrisRadar);
        if (_d isKindOf "UAV_01_base_F") then { _p = _p * CQ_tigrisSpotSize };
        if (random 1 < _p) then {
            _trk set [hashValue _d, time + CQ_tigrisTrack];
            ["Tigris at %1 spotted MAGPIE %2 (%3 m)", [mapGridPosition _t, _d getVariable ["CQ_magName", typeOf _d], round (_d distance _t)]] call CQ_fnc_log;
        };
    } forEach _tgts;
    _t setVariable ["CQ_trk", _trk];
    _tgts = _tgts select { time < (_trk getOrDefault [hashValue _x, -1]) };
    _t setVehicleRadar ([2, 1] select (_tgts isNotEqualTo []));   // radar emits only while tracking (no free detection by the game AI)
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
            private _guided = random 1 < CQ_tigrisGuide;      // otherwise the missile flies on its own lock: often a miss
            _t setVariable ["CQ_missileTgt", [objNull, _tgt] select _guided];
            _t selectWeaponTurret [_mw, [0]];
            if (_t fireAtTarget [_tgt, _mw]) then {
                _t setVariable ["CQ_salvoT", time + CQ_tigrisSalvo];
                ["Tigris at %1 fires a missile at MAGPIE %2 (%3 m, %4)", [mapGridPosition _t, _tgt getVariable ["CQ_magName", typeOf _tgt], round (_tgt distance _t), ["unguided", "guided"] select _guided]] call CQ_fnc_log;
            };
            _t setVariable ["CQ_missileTgt", objNull];
        };
    };
    if (time - (_t getVariable ["CQ_lockLogT", -1e6]) > 30) then {
        _t setVariable ["CQ_lockLogT", time];
        if (CQ_logVerbose) then { ["Tigris at %1 locked MAGPIE %2 (%3 m)", [mapGridPosition _t, _tgt getVariable ["CQ_magName", typeOf _tgt], round (_tgt distance _t)]] call CQ_fnc_log };
    };
} forEach CQ_tigrises;
