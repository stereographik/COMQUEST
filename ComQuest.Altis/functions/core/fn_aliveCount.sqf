/*
    CQ_fnc_aliveCount
    [_groups] call CQ_fnc_aliveCount  ->  number of living units in those groups
*/
params [["_groups", [], [[]]]];
private _n = 0;
{ if (!isNull _x) then { _n = _n + ({ alive _x } count units _x) } } forEach _groups;
_n
