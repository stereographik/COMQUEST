/*
    CQ_fnc_crashRoam  (server, spawned)
    [_vehicle, _site] spawn CQ_fnc_crashRoam;
    The vehicle the carrier dropped on the crash site roams around it for CQ_crashRoam s, its
    radius going close -> large -> close (CQ_crashRoamR), then drives to the nearest enemy HQ and
    joins its vehicles (the network's roaming then takes over).
*/
params ["_v", "_site"];
private _g = group effectiveCommander _v;
private _t0 = time;
CQ_crashRoamR params ["_r0", "_r1"];
while { alive _v && { time - _t0 < CQ_crashRoam } && { ({ alive _x } count units _g) > 0 } } do {
    private _k = (time - _t0) / CQ_crashRoam;
    private _r = _r0 + (_r1 - _r0) * sin (180 * _k);
    private _p = _site getPos [_r, random 360];
    if (surfaceIsWater _p) then { _p = _site };
    [_g] call CQ_fnc_clearWaypoints;
    private _wp = _g addWaypoint [_p, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointSpeed "LIMITED";
    _g setCurrentWaypoint _wp;
    sleep 45;
};
if (!alive _v) exitWith { ["Crash event: the dropped %1 was destroyed", [typeOf _v]] call CQ_fnc_log };
private _hqs = (values CQ_hqs) select { (_x get "state") in CQ_activeStates };
if (_hqs isEqualTo []) exitWith {};
private _h = ([_hqs, [], { (_x get "pos") distance2D _v }] call BIS_fnc_sortBy) select 0;
[_g] call CQ_fnc_clearWaypoints;
(_g addWaypoint [_h get "pos", 100]) setWaypointType "MOVE";
_v setVariable ["CQ_hqId", _h get "id", true];
(_h get "vehicles") pushBack _v;
["Crash event: the dropped %1 joins HQ #%2", [typeOf _v, _h get "id"]] call CQ_fnc_log;
