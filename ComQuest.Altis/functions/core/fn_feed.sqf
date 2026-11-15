/*
    CQ_fnc_feed  (every machine, remoteExec'd by the server or a client)
    [_text] call CQ_fnc_feed;      or [[_line1, _line2]] for several lines
    One line in everyone's chat for the player feed: joins, departures, players down / killed.
*/
params ["_t"];
if (!hasInterface) exitWith {};
if (_t isEqualType []) then { { if (_x != "") then { systemChat _x } } forEach _t } else { systemChat _t };   // an array: one chat line each
