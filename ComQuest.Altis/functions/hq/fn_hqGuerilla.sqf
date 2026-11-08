/*
    CQ_fnc_hqGuerilla  (server, from CQ_fnc_hqBuild when stage 4 is done)
    [_hq] call CQ_fnc_hqGuerilla;
    The HQ arms the locals: CQ_guerillaSquads squads of FIA irregulars (vanilla O_G_* units,
    on the CSAT side) appear in the nearest village within CQ_guerillaVillageRange, or around
    the HQ, and patrol there. Limited ammo like every enemy soldier (CQ_fnc_unitPrep).
    Kept in the HQ's "guerilla" list: they never leave on colonisations, QRFs or transfers.
    Respects the CQ_maxAI cap.
*/
params ["_hq"];

private _c = _hq get "pos";
private _id = _hq get "id";
private _towns = nearestLocations [_c, ["NameVillage", "NameCity", "NameCityCapital", "NameLocal"], CQ_guerillaVillageRange];
private _ctr = if (_towns isEqualTo []) then { _c } else { locationPosition (_towns select 0) };
private _place = if (_towns isEqualTo []) then { "around the HQ" } else { format ["in %1", text (_towns select 0)] };

private _made = [];
for "_i" from 1 to CQ_guerillaSquads do {
    private _size = (CQ_guerillaSize select 0) + floor random ((CQ_guerillaSize select 1) - (CQ_guerillaSize select 0) + 1);
    if ((call CQ_fnc_enemyCount) + _size > CQ_maxAI) exitWith { ["HQ #%1: AI cap, no more guerillas", [_id]] call CQ_fnc_log };
    private _p = [_ctr getPos [50 + random 150, random 360], 4, 60] call CQ_fnc_clearPos;
    if (_p isEqualTo []) then { _p = _ctr getPos [80, random 360] };
    private _g = createGroup [east, true];
    private _classes = [CQ_guerillaLeader] + ((CQ_guerillaClasses call BIS_fnc_arrayShuffle) select [0, _size - 1]);
    while { count _classes < _size } do { _classes pushBack (selectRandom CQ_guerillaClasses) };
    { _g createUnit [_x, _p, [], 8, "NONE"] } forEach _classes;
    [units _g] call CQ_fnc_unitPrep;
    _g setVariable ["CQ_role", "guerilla"];
    _g setBehaviour "SAFE";
    _g setCombatMode "RED";
    _g enableDynamicSimulation CQ_dynSimGarrison;
    [_g, _ctr, [250, 500] select (_i > 1)] call CQ_fnc_infPatrol;
    _made pushBack _g;
};
if (_made isEqualTo []) exitWith {};
_hq set ["guerilla", (_hq getOrDefault ["guerilla", []]) + _made];
["Local guerillas armed", format ["HQ #%1 armed %2 locals %3 (grid %4): %5", _id, [_made] call CQ_fnc_aliveCount, _place, mapGridPosition _ctr, (_made apply { groupId _x }) joinString ", "]] call CQ_fnc_announce;
