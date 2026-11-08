/*
    CQ_fnc_notifyClient  (client, called by CQ_fnc_announce through remoteExec)
*/
params [["_title", "", [""]], ["_text", "", [""]]];

if (!hasInterface) exitWith {};

["CQ_Phase", [_title, _text]] call BIS_fnc_showNotification;
systemChat format ["[ComQuest] %1: %2", _title, _text];
