/*
    CQ_fnc_sniperRun  (server, scheduled)
    [_vehicle, _teamGroup, [_key, _spots, _hqId], _tag] call CQ_fnc_sniperRun;
    One sniper per spot. With a support team: they board its Strider (seats kept free for
    them, CQ_sniperSeats), the team drives to CQ_sniperDrop m short of the spots (on the HQ
    side) and drops them, then goes back to work. Without (objNull): they start at their HQ
    and walk. On its spot each sniper goes prone, watches the west and stays.
*/
params ["_v", "_g", "_job", "_tag"];
_job params ["", "_spots", "_id"];
private _hq = CQ_hqs getOrDefault [_id, createHashMap];
private _c = if (count _hq > 0) then { _hq get "pos" } else { _spots select 0 };
private _cls = [CQ_sniperClass, "O_soldier_M_F"] select !(isClass (configFile >> "CfgVehicles" >> CQ_sniperClass) && { getText (configFile >> "CfgVehicles" >> CQ_sniperClass >> "DLC") == "" });

private _sg = createGroup [east, true];
private _start = if (isNull _v) then { _c getPos [30, random 360] } else { getPosATL _v };
private _men = _spots apply {
    private _u = _sg createUnit [_cls, _start, [], 8, "NONE"];
    [[_u]] call CQ_fnc_unitPrep;
    _u
};
_sg setGroupIdGlobal [format ["Sniper team HQ%1", _id]];
_sg setBehaviour "STEALTH";
_sg setCombatMode "RED";
_sg enableDynamicSimulation false;

if (!isNull _v && { alive _v }) then {
    { _x moveInCargo _v } forEach _men;
    // drop point: CQ_sniperDrop m from the middle of the spots, toward the HQ, on a road if one is near
    private _mid = [0, 0, 0];
    { _mid = _mid vectorAdd _x } forEach _spots;
    _mid = _mid vectorMultiply (1 / count _spots);
    private _drop = _mid getPos [CQ_sniperDrop, _mid getDir _c];
    private _rd = (_drop nearRoads 120) select { isOnRoad _x };
    if (_rd isNotEqualTo []) then { _drop = getPosATL (_rd select 0) };
    [_g] call CQ_fnc_clearWaypoints;
    _g move _drop;
    ["%1 drives %2 snipers to grid %3", [_tag, count _men, mapGridPosition _drop]] call CQ_fnc_log;
    private _t0 = time;
    waitUntil { sleep 3; !alive _v || { (_v distance2D _drop < 40) && { speed _v < 4 } } || { time - _t0 > 600 } || { ({ alive _x } count units _g) == 0 } };
    { unassignVehicle _x; moveOut _x } forEach (_men select { alive _x && { vehicle _x == _v } });
    [_g] call CQ_fnc_clearWaypoints;
};

// each sniper to his spot; there: prone, eyes west, stays
{
    private _u = _x;
    private _p = _spots select _forEachIndex;
    if (!alive _u) then { continue };
    [_u, _p] spawn {
        params ["_u", "_p"];
        _u doMove _p;
        private _t0 = time;
        waitUntil { sleep 4; !alive _u || { _u distance2D _p < 6 } || { time - _t0 > 900 } };
        if (!alive _u) exitWith {};
        doStop _u;
        _u setUnitPos "DOWN";
        _u setDir 270;
        _u doWatch (_p getPos [1000, 270]);
        _u disableAI "PATH";
        ["Sniper in position at grid %1", [mapGridPosition _u]] call CQ_fnc_log;
    };
} forEach _men;
