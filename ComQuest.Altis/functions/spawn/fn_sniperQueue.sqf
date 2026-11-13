/*
    CQ_fnc_sniperQueue  (server, spawned once per carrier insertion)
    [_hqId] spawn CQ_fnc_sniperQueue;
    CQ_snipersPerWave snipers for this HQ, on high ground about 1 km on its west side
    (CQ_fnc_sniperSpots). They ride in the medic and engineer teams' Marids: each team gets a
    job with half of the spots (CQ_sniperJobs), picks it up before its next medic / repair job,
    drives to CQ_sniperDrop m from the spots and drops them (CQ_fnc_sniperRun). A job no team
    has taken after CQ_sniperWait s (team dead, none left) is done on foot from the HQ.
*/
params ["_id"];
private _hq = CQ_hqs getOrDefault [_id, createHashMap];
if (count _hq == 0) exitWith {};
private _spots = [_hq get "pos", CQ_snipersPerWave] call CQ_fnc_sniperSpots;
if (_spots isEqualTo []) exitWith { ["Snipers for HQ #%1: no high ground found on the west side", [_id]] call CQ_fnc_log };
_spots = [_spots, [], { (_hq get "pos") getDir _x }, "ASCEND"] call BIS_fnc_sortBy;
private _half = ceil (count _spots / 2);
if (isNil "CQ_sniperJobs") then { CQ_sniperJobs = createHashMapFromArray [["medic", []], ["engineer", []]] };
private _jobs = [["medic", _spots select [0, _half]], ["engineer", _spots select [_half]]] select { (_x select 1) isNotEqualTo [] };
private _keys = [];
{
    _x params ["_kind", "_ps"];
    private _key = format ["%1_%2_%3", _id, _kind, round time];
    (CQ_sniperJobs get _kind) pushBack [_key, _ps, _id];
    _keys pushBack [_kind, _key];
} forEach _jobs;
["Snipers for HQ #%1: %2 overwatch spots (%3), waiting for the support teams", [_id, count _spots, (_spots apply { mapGridPosition _x }) joinString ", "]] call CQ_fnc_log;

sleep CQ_sniperWait;
{
    _x params ["_kind", "_key"];
    private _list = CQ_sniperJobs get _kind;
    private _i = _list findIf { (_x select 0) == _key };
    if (_i > -1) then {
        private _job = _list deleteAt _i;
        ["Snipers for HQ #%1: no %2 team took them, they walk", [_id, _kind]] call CQ_fnc_log;
        [objNull, grpNull, _job, "on foot"] spawn CQ_fnc_sniperRun;
    };
} forEach _keys;
