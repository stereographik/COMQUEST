/*
    CQ_fnc_statsAdd  (server; clients reach it through remoteExec)
    [_player, [[key, value], ...]] call CQ_fnc_statsAdd;
    Adds to a player's statistics (CQ_stats: uid -> HashMap). "longest" keeps the maximum,
    every other key is summed. Published by CQ_fnc_statsTick. Nothing is stored on disk.
*/
params ["_u", ["_pairs", []]];
if (!isServer || { isNull _u } || { !isPlayer _u }) exitWith {};
if (isNil "CQ_stats") then { CQ_stats = createHashMap };
private _uid = getPlayerUID _u;
private _s = CQ_stats getOrDefault [_uid, createHashMap];
if (count _s == 0) then { CQ_stats set [_uid, _s] };
_s set ["#name", name _u];
{
    _x params ["_k", "_v"];
    if (_k == "longest") then { _s set [_k, (_s getOrDefault [_k, 0]) max _v] }
    else { _s set [_k, (_s getOrDefault [_k, 0]) + _v] };
} forEach _pairs;
CQ_statsDirty = true;
