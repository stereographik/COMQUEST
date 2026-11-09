/*
    CQ_fnc_statsTick  (server, director task)
    Every 5 s, if anything changed: publishes CQ_statsPub = [[uid, name, class, [values in
    CQ_statKeys order]], ...] to every client (squad manager STATS tab).
*/
if (time < CQ_statsNext) exitWith {};
CQ_statsNext = time + 5;
if (!CQ_statsDirty) exitWith {};
CQ_statsDirty = false;
private _online = createHashMap;
{ _online set [getPlayerUID _x, _x] } forEach allPlayers;
private _pub = [];
{
    private _p = _online getOrDefault [_x, objNull];
    private _cls = if (isNull _p) then { _y getOrDefault ["#class", "Rifleman"] } else { _p getVariable ["CQ_class", "Rifleman"] };
    _y set ["#class", _cls];
    _pub pushBack [_x, _y getOrDefault ["#name", "?"], _cls, CQ_statKeys apply { _y getOrDefault [_x, 0] }];
} forEach CQ_stats;
CQ_statsPub = _pub;
publicVariable "CQ_statsPub";
