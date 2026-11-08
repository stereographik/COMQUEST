/*
    CQ_fnc_hqNew  (server)
    [_pos, _parentId] call CQ_fnc_hqNew  ->  HQ record (HashMap), stored in CQ_hqs by id.
    States: Inbound -> Establishing -> Holding -> (Expanding, milestone 5) -> Destroyed | Failed
*/
params ["_pos", ["_parent", -1]];

private _id = CQ_hqNextId;
CQ_hqNextId = CQ_hqNextId + 1;

private _hq = createHashMapFromArray [
    ["id", _id],
    ["pos", _pos],
    ["dir", random 360],
    ["parent", _parent],
    ["state", "Inbound"],
    ["born", serverTime],
    ["objects", []],
    ["groups", []],
    ["building", objNull],
    ["commander", objNull],
    ["radio", objNull],
    ["depot", objNull],
    ["markers", []]
];

CQ_hqs set [_id, _hq];
_hq
