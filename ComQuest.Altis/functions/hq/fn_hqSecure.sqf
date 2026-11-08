/*
    CQ_fnc_hqSecure  (server)
    [_hq] call CQ_fnc_hqSecure;
    Start of the Securing phase: each infantry squad posts out to its own point on a
    CQ_secureRadius ring (spread evenly), armed vehicles drive one loop of the ring,
    the commander and the truck wait at the site. CQ_fnc_hqTick ends the phase when every
    squad has reached its post (or after CQ_secureTimeout).
*/
params ["_hq"];

private _c = _hq get "pos";
private _id = _hq get "id";
private _groups = (_hq get "infantry") select { ({ alive _x } count units _x) > 0 };
private _n = count _groups max 1;

{
    private _g = _x;
    [_g] call CQ_fnc_clearWaypoints;
    _g setVariable ["CQ_role", "secure"];

    private _a = (_hq get "dir") + _forEachIndex * (360 / _n);
    private _r = CQ_secureRadius;
    private _p = _c getPos [_r, _a];
    while { surfaceIsWater _p && { _r > 200 } } do { _r = _r - 100; _p = _c getPos [_r, _a] };

    private _wp = _g addWaypoint [_p, 30];
    _wp setWaypointType "MOVE";
    _wp setWaypointBehaviour "AWARE";
    _wp setWaypointSpeed "FULL";
    _wp setWaypointCompletionRadius 40;
    _g setVariable ["CQ_securePos", _p];
} forEach _groups;

// Armed vehicles: one loop of the perimeter, then back to the site. The truck waits.
{
    private _v = _x;
    private _vg = group effectiveCommander _v;
    if (alive _v && { !isNull _vg }) then {
        [_vg] call CQ_fnc_clearWaypoints;
        if (_v isKindOf "Truck_F") then {
            _vg move (_c getPos [35, (_hq get "dir") + 270]);
        } else {
            for "_a" from 0 to 300 step 60 do {
                private _p = _c getPos [CQ_secureRadius * 0.9, (_hq get "dir") + _a];
                if (!surfaceIsWater _p) then {
                    private _wp = _vg addWaypoint [_p, 50];
                    _wp setWaypointBehaviour "AWARE";
                };
            };
            _vg addWaypoint [_c getPos [60, random 360], 20];
        };
    };
} forEach (_hq get "vehicles");

private _cmd = _hq get "cmdGroup";
if (!isNull _cmd) then { _cmd move (_c getPos [15, (_hq get "dir") + 180]) };

_hq set ["secureStarted", true];
_hq set ["stateT", time];
["Enemy securing perimeter", format ["HQ #%1: %2 squads posting out to a %3 m perimeter around grid %4",
    _id, count _groups, CQ_secureRadius, mapGridPosition _c]] call CQ_fnc_announce;
