/*
    CQ_fnc_hqFallen  (server, from CQ_fnc_hqTick when an HQ falls)
    [_hq] spawn CQ_fnc_hqFallen;
    Nothing of a fallen HQ keeps working for it:
      - its helicopters re-base on the nearest standing HQ (none left: they stay where they are)
      - its infantry, vehicles, snipers and Tigris fall back to the nearest standing HQ and join it
      - CQ_hqFallenBlow s later its depot and tanker are blown up by the leaving troops
        (no score, no "objective destroyed" announce: the HQ is already counted as fallen)
*/
params ["_hq"];
private _id = _hq get "id";
private _c = _hq get "pos";

private _act = (values CQ_hqs) select { (_x get "state") in CQ_activeStates && { (_x get "id") != _id } };
private _to = if (_act isEqualTo []) then { createHashMap } else { ([_act, [], { (_x get "pos") distance2D _c }, "ASCEND"] call BIS_fnc_sortBy) select 0 };

// ---- helicopters
private _nAir = 0;
{
    private _e = _x;
    if (alive (_e get "veh") && { (_e get "homeId") == _id || { (_e get "pad") distance2D _c < 400 } } && { (_e get "state") in ["parked", "toPark", "patrolling"] }) then {
        if (count _to > 0) then {
            private _oldPad = _e get "pad";
            if (((values CQ_hqs) findIf { (_x get "pad") isEqualTo _oldPad }) == -1) then { deleteVehicle _oldPad };
            _e set ["homeId", _to get "id"];
            _e set ["pad", [_to get "pos", 50, 220] call CQ_fnc_airParkSpot];
        } else {
            _e set ["homeId", -1];
        };
        if ((_e get "state") in ["parked", "toPark"]) then {
            (_e get "veh") engineOn true;
            _e set ["state", "toPark"];
            _e set ["nearT", -1];
            if (count _to > 0) then { (_e get "veh") doMove (getPosATL (_e get "pad")) };
        };
        _nAir = _nAir + 1;
    };
} forEach CQ_air;

// ---- troops, vehicles, snipers, Tigris
private _nGrp = 0;
if (count _to > 0) then {
    private _tid = _to get "id";
    private _tp = _to get "pos";
    {
        if (!isNull _x && { ({ alive _x } count units _x) > 0 }) then {
            [_x] call CQ_fnc_clearWaypoints;
            _x setVariable ["CQ_role", "patrol"];
            _x setBehaviour "AWARE"; _x setSpeedMode "FULL";
            { _x setVariable ["CQ_hqId", _tid] } forEach units _x;
            [_x, _tp, 250] call CQ_fnc_infPatrol;
            (_to get "infantry") pushBack _x;
            _nGrp = _nGrp + 1;
        };
    } forEach ((_hq get "infantry") + [_hq get "cmdGroup"]);
    _hq set ["infantry", []];
    {
        if (alive _x && { canMove _x } && { ({ alive _x } count crew _x) > 0 }) then {
            private _g = group effectiveCommander _x;
            [_g] call CQ_fnc_clearWaypoints;
            _g setVariable ["CQ_role", "patrol"];
            _x setVariable ["CQ_hqId", _tid, true];
            { _x setVariable ["CQ_hqId", _tid] } forEach crew _x;
            [_g, _x, _tp] call CQ_fnc_vehRoam;
            (_to get "vehicles") pushBack _x;
            _nGrp = _nGrp + 1;
        };
    } forEach (_hq get "vehicles");
    _hq set ["vehicles", []];
    {
        if (alive _x) then {
            _x setVariable ["CQ_hqId", _tid];
            [_x, ([_tp, 1, 500] call CQ_fnc_sniperSpots) param [0, _tp getPos [300, random 360]]] spawn CQ_fnc_sniperPost;
            (_to getOrDefault ["snipers", []]) pushBack _x;
        };
    } forEach (_hq getOrDefault ["snipers", []]);
    {
        if (alive _x && { (_x getVariable ["CQ_hqId", -1]) == _id } && { canMove _x }) then {
            _x setVariable ["CQ_hqId", _tid, true];
            private _g = group effectiveCommander _x;
            [_g] call CQ_fnc_clearWaypoints;
            _g move (_tp getPos [350 + random 250, random 360]);
        };
    } forEach (missionNamespace getVariable ["CQ_tigrises", []]);
};
["HQ #%1 fallen: %2 aircraft re-based, %3 groups fall back to %4", [_id, _nAir, _nGrp, if (count _to > 0) then { format ["HQ #%1", _to get "id"] } else { "nowhere (none left)" }]] call CQ_fnc_log;

// ---- depot and tanker: blown up by the leaving troops
sleep CQ_hqFallenBlow;
{
    private _o = _hq getOrDefault [_x, objNull];
    if (alive _o) then {
        _o setDamage 1;
        ["HQ #%1 fallen: its %2 blown up", [_id, _x]] call CQ_fnc_log;
    };
} forEach ["depot", "tanker"];
