/*
    CQ_fnc_opSide  (server)
    [_key, _state, _label, _result, _who] call CQ_fnc_opSide;
    One line of the OPERATION briefing's "Side events" section (CQ_fnc_opTick): crash site,
    hostage... _key identifies the event (the same key updates its line), _state 1 active /
    2 over, _label what it is, _result how it ended (shown with the time and the squad).
*/
params ["_key", "_state", "_label", ["_result", ""], ["_who", objNull]];
if (!isServer) exitWith {};
if (isNil "CQ_op") then { CQ_op = createHashMap };
private _side = CQ_op getOrDefault ["side", []];
private _i = _side findIf { (_x select 0) == _key };
private _sq = if (!isNull _who && { isPlayer _who }) then { groupId group _who } else { "" };
private _row = [_key, _state, _label, _result, time, _sq];
if (_i < 0) then { _side pushBack _row } else { _side set [_i, _row] };
CQ_op set ["side", _side];
CQ_opNext = 0;      // refresh the briefing at once
