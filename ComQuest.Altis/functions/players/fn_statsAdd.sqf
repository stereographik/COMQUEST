/*
    CQ_fnc_statsAdd  (server; clients reach it through remoteExec)
    [_player, [[key, value], ...]] call CQ_fnc_statsAdd;
    Adds to a player's statistics (CQ_stats: uid -> HashMap). "longest" keeps the maximum,
    every other key is summed. Published by CQ_fnc_statsTick. Nothing is stored on disk.
    Also credits the player's squad with combat points (CQ_squadPointWeights) for the shop.
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
// squad combat points (vehicle shop): credited to the player's squad
private _g = group _u;
if !(_g getVariable ["CQ_solo", true]) then {
    private _sp = 0;
    {
        _x params ["_k", "_v"];
        private _w = CQ_squadPointWeights findIf { (_x select 0) == _k };
        if (_w > -1 && { _k != "longest" }) then { _sp = _sp + _v * ((CQ_squadPointWeights select _w) select 1) };
    } forEach _pairs;
    if (_sp != 0) then { _g setVariable ["CQ_sqPts", ((_g getVariable ["CQ_sqPts", 0]) + _sp) max 0, true] };
};
