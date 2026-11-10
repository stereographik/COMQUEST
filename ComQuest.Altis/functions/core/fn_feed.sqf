/*
    CQ_fnc_feed  (every machine, remoteExec'd by the server or a client)
    [_text] call CQ_fnc_feed;
    One line in everyone's chat for the player feed: joins, departures, players down / killed.
*/
params ["_t"];
if (!hasInterface) exitWith {};
systemChat _t;
