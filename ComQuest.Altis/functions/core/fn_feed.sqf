/*
    CQ_fnc_feed  (every machine, remoteExec'd by the server or a client)
    [_text] call CQ_fnc_feed;      or [[_line1, _line2]] for several lines
    The player feed for everyone: joins, departures, players down / killed / revived, in the same
    on-screen list as the enemy vehicle kills (CQ_fnc_vehFeed: last CQ_vehFeedMax entries).
*/
params ["_t"];
if (!hasInterface) exitWith {};
// shown in the on-screen list of the last kills (CQ_fnc_vehFeed), not in the chat: a line and its remark
if (_t isEqualType []) then { _t params [["_l", ""], ["_r", ""]]; ["show", [_l, _r]] call CQ_fnc_vehFeed } else { ["show", [_t, ""]] call CQ_fnc_vehFeed };
