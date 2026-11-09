/*
    CQ_fnc_scoreAdd  (server)
    [_unit, _points, _what] call CQ_fnc_scoreAdd;
    Extra score for mission objectives (radio tower, depot, commander, supply flight...).
    Kept in memory only: CQ_scoreTable = [[uid, name, objectives, points], ...], sent to every
    client; wiped by a server restart. Kills and deaths come from Arma's own player scores.
*/
params ["_u", "_pts", ["_what", ""]];
if (!isServer || { isNull _u } || { !isPlayer _u }) exitWith {};
if (isNil "CQ_scoreTable") then { CQ_scoreTable = [] };
private _uid = getPlayerUID _u;
private _i = CQ_scoreTable findIf { (_x select 0) == _uid };
if (_i < 0) then { CQ_scoreTable pushBack [_uid, name _u, 0, 0]; _i = count CQ_scoreTable - 1 };
private _r = CQ_scoreTable select _i;
_r set [1, name _u];
_r set [2, (_r select 2) + 1];
_r set [3, (_r select 3) + _pts];
publicVariable "CQ_scoreTable";
["Score: %1 +%2 (%3)", [name _u, _pts, _what]] call CQ_fnc_log;

// detailed statistics
private _k = switch (_what) do {
    case "supply depot": { "objDepot" };
    case "radio tower": { "objTower" };
    case "HQ commander": { "objCmdKilled" };
    case "HQ commander captured": { "objCmdCaptured" };
    default { "" };
};
private _pairs = [["objPoints", _pts]];
if (_k != "") then { _pairs pushBack [_k, 1] };
[_u, _pairs] call CQ_fnc_statsAdd;
