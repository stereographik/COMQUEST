/*
    CQ_fnc_airRegister  (server)
    [_heli, _group, _kind, _homeHqId, _pad, _fallbackPos, _parked] call CQ_fnc_airRegister  ->  bool
    Puts a helicopter under the air manager (CQ_fnc_airTick).
      _kind      "armed" (hunts, limited ammo, rearms) or "transport" (waits for orders)
      _homeHqId  -1 = fleet based at the main HQ (refused when CQ_fleetMax is reached),
                 otherwise the HQ that owns it (its QRF Orca)
      _pad       its parking pad; objNull = a new spot near the main HQ (or _fallbackPos)
*/
params ["_heli", "_grp", "_kind", ["_homeId", -1], ["_pad", objNull], ["_fallback", []], ["_parked", false]];

if (_homeId == -1 && { ({ (_x get "homeId") == -1 } count CQ_air) >= CQ_fleetMax }) exitWith { false };

if (isNull _pad) then {
    private _hub = CQ_hqs getOrDefault [CQ_hubId, createHashMap];
    private _center = if (count _hub > 0) then { _hub get "pos" } else { _fallback };
    if (_center isEqualTo []) then { _center = getPosATL _heli };
    _pad = [_center] call CQ_fnc_airParkSpot;
};

private _e = createHashMapFromArray [
    ["veh", _heli], ["grp", _grp], ["kind", _kind], ["homeId", _homeId], ["pad", _pad],
    ["state", ["toPark", "parked"] select _parked], ["landing", false], ["until", 0], ["target", -1]
];
CQ_air pushBack _e;

if (!_parked) then {
    [_grp] call CQ_fnc_clearWaypoints;
    _heli flyInHeight 60;
    _heli doMove (getPosATL _pad);
};
["Air: %1 %2 registered (home %3), fleet size %4", [_kind, typeOf _heli, ["main HQ", format ["HQ #%1", _homeId]] select (_homeId > -1), count CQ_air]] call CQ_fnc_log;
true
