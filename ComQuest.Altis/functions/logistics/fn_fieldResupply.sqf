/*
    CQ_fnc_fieldResupply  (server, spawned by CQ_fnc_fieldResupplyTry)
    [_hq, _group, _load] spawn CQ_fnc_fieldResupply;
    The HQ's field supply truck gets a crew, drives to the waiting group, rearms every soldier
    within 50 m (paid from the _load it carries), drives back, returns what is left to the
    depot and parks again (crew removed). Destroyed on the way = load lost.
*/
params ["_hq", "_g", "_load"];

private _id = _hq get "id";
private _truck = _hq get "fieldTruck";
private _home = _hq get "fieldTruckHome";
if (_home isEqualTo []) then { _home = getPosATL _truck };

_truck lock 0;
private _cg = [_truck] call CQ_fnc_crewVehicle;
_cg setBehaviour "SAFE";
_cg setSpeedMode "FULL";

["Enemy field resupply", format ["HQ #%1 sends its ammo truck (%2 ammo) to %3, %4 m out at grid %5",
    _id, round _load, groupId _g, round ((leader _g) distance2D _truck), mapGridPosition leader _g]] call CQ_fnc_announce;

// --- out to the group
private _done = false;
private _lost = false;
private _t0 = time;
private _lastMove = -100;
while { true } do {
    sleep 3;
    if (!alive _truck || { !alive driver _truck }) exitWith { _lost = true };
    if (({ alive _x } count units _g) == 0) exitWith {};
    if (time - _t0 > 900) exitWith { ["HQ #%1: field truck never reached %2", [_id, groupId _g]] call CQ_fnc_log };

    private _target = getPosATL leader _g;
    if (_truck distance2D _target > 40) then {
        if (time - _lastMove > 10) then { _cg move _target; _lastMove = time };
    } else {
        sleep 10;
        if (alive _truck) then {
            private _before = _load;
            { if (alive _x && { _x distance _truck < 50 }) then { _load = [_x, _load] call CQ_fnc_rearmUnit } } forEach units _g;
            ["HQ #%1: field truck rearmed %2 (%3 ammo used, ammo now %4%%)", [_id, groupId _g, round (_before - _load), round (100 * ([_g] call CQ_fnc_infAmmo))]] call CQ_fnc_log;
        };
        _done = true;
    };
    if (_done) exitWith {};
};

// The group goes back to what it was doing
if (({ alive _x } count units _g) > 0 && { (_g getVariable ["CQ_role", ""]) == "waitSupply" }) then {
    private _prev = _g getVariable ["CQ_prevRole", "patrol"];
    _g setVariable ["CQ_role", _prev];
    if (_prev != "qrf") then { [_g, _hq get "pos", CQ_patrolRadius select 0] call BIS_fnc_taskPatrol };
};

if (_lost) exitWith {
    _hq set ["fieldRun", false];
    ["Enemy field truck destroyed", format ["HQ #%1 lost its field supply truck with %2 ammo", _id, round _load]] call CQ_fnc_announce;
};

// --- back home and park
_cg move _home;
_t0 = time;
waitUntil { sleep 3; !alive _truck || { !alive driver _truck } || { _truck distance2D _home < 25 } || { time - _t0 > 600 } };

if (alive _truck) then {
    if ((_hq get "state") in CQ_activeStates && { alive (_hq get "depot") }) then {
        _hq set ["stock", ((_hq get "stock") + _load) min (_hq get "cap")];
    };
    { deleteVehicle _x } forEach crew _truck;
    deleteGroup _cg;
    _truck lock 2;
} else {
    ["Enemy field truck destroyed", format ["HQ #%1 lost its field supply truck on the way back", _id]] call CQ_fnc_announce;
};
_hq set ["fieldRun", false];
