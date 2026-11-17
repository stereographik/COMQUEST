/*
    CQ_fnc_endgame  (server)
    ["win", "reason"] call CQ_fnc_endgame;   /   ["lose", "reason"] call CQ_fnc_endgame;
    End of the game (victory or defeat). Builds the DEBRIEF package, publishes it to every player
    (CQ_endPub, shown on the field tablet by CQ_fnc_endgameUi), then the next game starts after
    CQ_endWait s (the mission ends: the server loads the next one).
    CQ_endPub = [result, reason, duration s, end serverTime, players,
                 [HQs destroyed, HQs in all], enemy killed, our deaths, HQs sent by the carrier,
                 timeline [[name, born, found, fell], ...] (times in s from the game start, -1 = never),
                 players [[uid, name, squad, class, points, kills, deaths, objectives, heals,
                           best weapon, its kills, longest kill, events, km driven, km on foot], ...],
                 awards [[title, icon, uid, name, stat text, fun], ...]]
    Awards: one winner each (ties: the player with more points); an award nobody earned is left out.
*/
params [["_res", "win"], ["_why", ""]];
if (!isServer || { !isNil "CQ_endPub" }) exitWith {};
private _t0 = missionNamespace getVariable ["CQ_opStartT", 0];
private _dur = round (time - _t0);
private _rel = { params ["_t"]; if (_t < 0) then { -1 } else { round ((_t - _t0) max 0) } };

// ---- players (every player that played, online or not)
private _online = createHashMap;
{ _online set [getPlayerUID _x, _x] } forEach allPlayers;
private _stats = missionNamespace getVariable ["CQ_stats", createHashMap];
private _rows = [];
{
    private _uid = _x; private _s = _y;
    private _p = _online getOrDefault [_uid, objNull];
    private _pts = 0;
    { _x params ["_k", "_w"]; _pts = _pts + (_s getOrDefault [_k, 0]) * _w } forEach CQ_statWeights;
    // best weapon: the "w:<name>" key with the most kills
    private _bw = "-"; private _bk = 0;
    { if ((_x select [0, 2]) == "w:" && { (_s get _x) > _bk }) then { _bk = _s get _x; _bw = _x select [2] } } forEach (keys _s);
    _rows pushBack [_uid, _s getOrDefault ["#name", "?"], (if (isNull _p) then { "-" } else { [groupId group _p, "no squad"] select ((group _p) getVariable ["CQ_solo", true]) }), _s getOrDefault ["#class", "Rifleman"],
        round _pts, _s getOrDefault ["killsInf", 0], _s getOrDefault ["deaths", 0], _s getOrDefault ["objAll", 0], _s getOrDefault ["heals", 0],
        _bw, _bk, _s getOrDefault ["longest", 0], _s getOrDefault ["events", 0],
        round ((_s getOrDefault ["distVeh", 0]) / 100) / 10, round ((_s getOrDefault ["distFoot", 0]) / 100) / 10,
        _s getOrDefault ["objCmdCaptured", 0], _s getOrDefault ["vehArmor", 0], _s getOrDefault ["vehAir", 0], _s getOrDefault ["shots", 0], _s getOrDefault ["timePlayed", 0]];
} forEach _stats;
_rows = [_rows, [], { _x select 4 }, "DESCEND"] call BIS_fnc_sortBy;

// ---- awards: [title, icon, row index, stat text, fun]; best value wins, ties to more points (rows are sorted)
private _ico = { "\A3\ui_f\data\igui\cfg\simpleTasks\types\" + _this + "_ca.paa" };
private _best = {
    params ["_i", ["_low", false], ["_filter", { true }]];
    private _w = -1; private _v = [-1e9, 1e9] select _low;
    { if ([_x] call _filter) then { private _c = _x select _i; if ((!_low && { _c > _v }) || { _low && { _c < _v } }) then { _v = _c; _w = _forEachIndex } } } forEach _rows;
    [_w, _v]
};
private _aw = [];
private _add = {
    params ["_title", "_icon", "_i", "_fmt", ["_fun", false], ["_low", false], ["_filter", { true }]];
    ([_i, _low, _filter] call _best) params ["_w", "_v"];
    if (_w < 0 || { !_low && { _v <= 0 } }) exitWith {};
    private _r = _rows select _w;
    _aw pushBack [_title, _icon call _ico, _r select 0, _r select 1, format [_fmt, _v], _fun];
};
["Top gun", "kill", 5, "%1 kills"] call _add;
["Sharpshooter", "target", 11, "kill at %1 m"] call _add;
["Demolition expert", "destroy", 7, "%1 objectives"] call _add;
["Guardian angel", "heal", 8, "%1 teammates healed"] call _add;
["Interrogator", "interact", 15, "%1 commander(s) captured"] call _add;
["Tank buster", "armor", 16, "%1 armoured vehicles"] call _add;
["Sky cleaner", "heli", 17, "%1 aircraft down"] call _add;
["Road warrior", "car", 13, "%1 km driven"] call _add;
["Marathon man", "run", 14, "%1 km on foot"] call _add;
if (!isNil "CQ_pathfinder") then { CQ_pathfinder params ["_u", "_n", "_t"]; _aw pushBack ["Pathfinder", "navigate" call _ico, _u, _n, format ["first at an enemy HQ, %1", [[_t] call _rel, "HH:MM:SS"] call BIS_fnc_secondsToString], false] };
["Iron man", "defend", 6, "%1 death(s)", false, true, { (_this select 0) select 19 >= 1800 }] call _add;
if (!isNil "CQ_firstBlood") then { CQ_firstBlood params ["_u", "_n", "_t"]; _aw pushBack ["First blood", "attack" call _ico, _u, _n, format ["first kill at %1", [[_t] call _rel, "HH:MM:SS"] call BIS_fnc_secondsToString], false] };
if (!isNil "CQ_lastHqKillerRec") then { CQ_lastHqKillerRec params ["_u", "_n"]; _aw pushBack ["Final blow", "whiteboard" call _ico, _u, _n, "the last HQ to fall", false] };
["Event hero", "intel", 12, "%1 side event(s) won"] call _add;
["Frequent flyer", "danger", 6, "%1 deaths", true] call _add;
["Trigger happy", "rifle", 18, "%1 shots fired", true] call _add;

// ---- the war: HQs, enemy losses, our losses, timeline
private _hqs = [values CQ_hqs, [], { _x get "id" }] call BIS_fnc_sortBy;
private _down = { (_x get "state") == "Destroyed" } count _hqs;
private _tl = _hqs apply { [_x get "name", [_x getOrDefault ["born", _t0]] call _rel, [_x getOrDefault ["foundT", -1]] call _rel, [_x getOrDefault ["fallT", -1]] call _rel] };
private _kia = 0; { _kia = _kia + (_x select 6) } forEach _rows;

// the MAP tab: each group's trace on the ground ([side, [[x, y, s from the start], ...]]), the HQs
private _trs = [];
{ if (count (_y select 1) > 1) then { _trs pushBack [_y select 0, (_y select 1) apply { [_x select 0, _x select 1, [_x select 2] call _rel] }] } } forEach (missionNamespace getVariable ["CQ_trace", createHashMap]);
CQ_endTrace = [_trs, _hqs apply { [_x get "pos", (_x get "state") == "Destroyed", _x get "name", [_x getOrDefault ["fallT", -1]] call _rel] }];
publicVariable "CQ_endTrace";

CQ_endPub = [_res, _why, _dur, serverTime + CQ_endWait, count _rows,
    [_down, count _hqs], missionNamespace getVariable ["CQ_enKilled", 0], _kia, count _hqs,
    _tl, _rows apply { _x select [0, 15] }, _aw];
publicVariable "CQ_endPub";
["ENDGAME: %1 (%2), %3 s, %4 players, %5 awards; next game in %6 s", [_res, _why, _dur, count _rows, count _aw, CQ_endWait]] call CQ_fnc_log;
[_res] spawn {
    params ["_res"];
    private _t = time + CQ_endWait;
    waitUntil { sleep 1; time >= _t || { missionNamespace getVariable ["CQ_endNow", false] } };   // debug "Next game now"
    ["save"] call CQ_fnc_carry;           // friendlies keep kit, class, squad, points and bought vehicles
    [["EveryoneLost", "EveryoneWon"] select (_res == "win")] call BIS_fnc_endMissionServer;
};
