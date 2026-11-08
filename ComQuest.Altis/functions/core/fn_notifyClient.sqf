/*
    CQ_fnc_notifyClient  (client, called by CQ_fnc_announce through remoteExec)
*/
params [["_title", "", [""]], ["_text", "", [""]]];

if (!hasInterface) exitWith {};

if (CQ_debugCards) then { ["CQ_Phase", [_title, _text]] call BIS_fnc_showNotification };
systemChat format ["[DEBUG] %1: %2", _title, _text];
