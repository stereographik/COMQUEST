/*
    CQ_fnc_opEvent  (server)
    [_type, _who] call CQ_fnc_opEvent;      _type: "convoy", "flight", "spectre"
    Counts a stacked event for the OPERATION briefing (CQ_fnc_opTick): how many, when the
    last one happened, and which squad did it (_who: the player responsible, or objNull).
*/
params ["_type", ["_who", objNull]];
if (isNil "CQ_op") then { CQ_op = createHashMap };
private _r = CQ_op getOrDefault [_type, [0, 0, ""]];
_r set [0, (_r select 0) + 1];
_r set [1, time];
if (!isNull _who && { isPlayer _who }) then { _r set [2, groupId group _who] };
CQ_op set [_type, _r];
CQ_opNext = 0;      // refresh the briefing at once
