/*
    CQ_fnc_crashStart  (server)
    [] call CQ_fnc_crashStart;   -> true if a crash site was placed
    The crash event: a CSAT transport down between the base and an enemy HQ. Places the wreck
    (smoke and fire), the crate of enemy comms gear (hold action "Secure enemy comms device") and
    the survivors guarding it. Clears the previous crash site first. State: CQ_crashState hashmap
      pos, objs (wreck, crate, effects), crate, group, contactT (-1), warned, dropped, secured, t0
*/
if (!isServer) exitWith { false };

// previous site out
if (!isNil "CQ_crashState") then {
    { if (!isNull _x) then { deleteVehicle _x } } forEach (CQ_crashState getOrDefault ["objs", []]);
    deleteMarker "cq_crash";
};
CQ_crashAlarm = false; publicVariable "CQ_crashAlarm";

// ---- site: between the base and an enemy HQ, flat and open, away from players
private _hqs = (values CQ_hqs) select { (_x get "state") in CQ_activeStates };
private _site = [];
for "_try" from 1 to 8 do {
    private _c = if (_hqs isEqualTo []) then {
        CQ_basePos getPos [4000 + random 3000, random 360]
    } else {
        private _h = selectRandom _hqs;
        private _f = (CQ_crashSiteFrac select 0) + random ((CQ_crashSiteFrac select 1) - (CQ_crashSiteFrac select 0));
        CQ_basePos vectorAdd (((_h get "pos") vectorDiff CQ_basePos) vectorMultiply _f)
    };
    _c = [_c select 0, _c select 1, 0];
    if (surfaceIsWater _c) then { continue };
    private _s = [_c, 0, 700, true, 40] call CQ_fnc_findSite;
    if (_s isEqualTo []) then { continue };
    if ((allPlayers findIf { alive _x && { _x distance2D _s < CQ_crashPlayerGap } }) > -1) then { continue };
    if (_s distance2D CQ_basePos < 2500) then { continue };
    _site = _s;
    break;
};
if (_site isEqualTo []) exitWith { ["Crash event: no site found this time"] call CQ_fnc_log; false };

// ---- wreck, effects, crate
private _objs = [];
private _wcls = CQ_crashWrecks param [CQ_crashWrecks findIf { isClass (configFile >> "CfgVehicles" >> _x) }, ""];
private _dir = random 360;
if (_wcls != "") then {
    private _w = createVehicle [_wcls, _site, [], 0, "CAN_COLLIDE"];
    _w setDir _dir;
    _w setVectorUp surfaceNormal _site;
    _objs pushBack _w;
};
{
    private _e = createVehicle [_x, _site getPos [4, _dir + 90], [], 0, "CAN_COLLIDE"];
    _objs pushBack _e;
} forEach ["test_EmptyObjectForSmoke", "test_EmptyObjectForFireBig"];
private _cp = _site getPos [14, _dir - 90];
_cp = [_cp select 0, _cp select 1, 0];
private _crate = createVehicle [CQ_crashCrate, _cp, [], 0, "CAN_COLLIDE"];
_crate allowDamage false;
clearWeaponCargoGlobal _crate; clearMagazineCargoGlobal _crate; clearItemCargoGlobal _crate; clearBackpackCargoGlobal _crate;
_crate setVariable ["CQ_crashCrate", true, true];
_objs pushBack _crate;
[_crate,
    "<t color='#918C3B'>Secure enemy comms device</t>",
    "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_search_ca.paa",
    "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_search_ca.paa",
    "_this distance _target < 3 && { alive _this } && { !(_target getVariable ['CQ_secured', false]) }",
    "_caller distance _target < 3",
    {}, {},
    { params ["_target", "_caller"]; [_caller] remoteExec ["CQ_fnc_crashSecure", 2] },
    {}, [], 3, 10, false, false
] remoteExec ["BIS_fnc_holdActionAdd", 0, _crate];

// ---- survivors: a sharp squad guarding the crate
private _g = createGroup [east, true];
{
    private _u = _g createUnit [_x, _cp getPos [6 + random 12, random 360], [], 0, "NONE"];
    _u setSkill CQ_crashSkill;
    _u setVariable ["CQ_crashSurvivor", true];
} forEach CQ_crashSurvivors;
[units _g] call CQ_fnc_unitPrep;
_g setGroupIdGlobal ["Crash survivors"];
_g setBehaviour "AWARE";
_g setCombatMode "RED";
_g enableDynamicSimulation false;
[_g, _cp, 40] call BIS_fnc_taskDefend;

// marker: the crash area
private _m = createMarker ["cq_crash", _site];
_m setMarkerShape "ELLIPSE";
_m setMarkerSize [250, 250];
_m setMarkerBrush "FDiagonal";
_m setMarkerColor "ColorOPFOR";

CQ_crashState = createHashMapFromArray [
    ["pos", _site], ["objs", _objs], ["crate", _crate], ["group", _g], ["contactT", -1],
    ["warned", false], ["dropped", false], ["secured", false], ["t0", time]
];
CQ_crashLastT = time;
CQ_crashPos = _site; publicVariable "CQ_crashPos";
["Crash event: CSAT transport down at %1 (%2 m from the base, %3 survivors, wreck %4)", [mapGridPosition _site, round (_site distance2D CQ_basePos), count units _g, _wcls]] call CQ_fnc_log;
["crashDown", [mapGridPosition _site]] call CQ_fnc_say;
true
