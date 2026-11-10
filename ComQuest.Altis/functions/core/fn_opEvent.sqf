/*
    CQ_fnc_opEvent  (server)
    [_type, _who] call CQ_fnc_opEvent;      _type: "convoy", "flight", "spectre"
    Records one event for the OPERATION briefing (CQ_fnc_opTick): every event is kept as its
    own line [time, squad] (_who: the player responsible, or objNull), so the briefing lists
    each convoy, flight or team instead of a stacked counter.
*/
params ["_type", ["_who", objNull]];
if (isNil "CQ_op") then { CQ_op = createHashMap };
private _l = CQ_op getOrDefault [_type + "List", []];
_l pushBack [time, if (!isNull _who && { isPlayer _who }) then { groupId group _who } else { "" }];
CQ_op set [_type + "List", _l];
CQ_opNext = 0;      // refresh the briefing at once
