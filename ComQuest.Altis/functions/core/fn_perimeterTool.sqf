/*
    CQ_fnc_perimeterTool  (client, base lab only)
    [] spawn CQ_fnc_perimeterTool;
    Draw a polygon on the map: left click adds a corner, BACKSPACE removes the last one,
    ENTER finishes (closes the polygon), the corners [x, y] are copied to the clipboard and
    written to the log ("[PERIM]"). The polygon stays drawn on the map until redrawn.
*/
if (!hasInterface) exitWith {};
CQ_perim = [];
CQ_perimDone = false;
openMap [true, false];
waitUntil { !isNull findDisplay 12 };
private _map = (findDisplay 12) displayCtrl 51;
if (isNil "CQ_perimDrawEH") then {
    CQ_perimDrawEH = _map ctrlAddEventHandler ["Draw", {
        params ["_m"];
        private _p = missionNamespace getVariable ["CQ_perim", []];
        private _n = count _p;
        { _m drawIcon ["\A3\ui_f\data\map\markers\military\dot_CA.paa", [1, 0.6, 0, 1], _x, 18, 18, 0, str (_forEachIndex + 1), 1, 0.05, "PuristaMedium", "right"] } forEach _p;
        for "_i" from 0 to _n - 2 do { _m drawLine [_p select _i, _p select (_i + 1), [1, 0.6, 0, 1]] };
        if (_n > 2 && { CQ_perimDone }) then { _m drawLine [_p select (_n - 1), _p select 0, [1, 0.6, 0, 1]] };
    }];
};
hint parseText "<t size='1.1'>BASE PERIMETER</t><br/>Left click: add a corner<br/>BACKSPACE: remove the last one<br/>ENTER: finish and export";
private _click = addMissionEventHandler ["MapSingleClick", {
    params ["", "_pos"];
    if (CQ_perimDone) exitWith {};
    CQ_perim pushBack [round (_pos select 0), round (_pos select 1)];
    hintSilent format ["Corner %1 at %2", count CQ_perim, CQ_perim select -1];
}];
private _key = (findDisplay 12) displayAddEventHandler ["KeyDown", {
    params ["", "_k"];
    if (_k == 14) exitWith { if (CQ_perim isNotEqualTo [] && { !CQ_perimDone }) then { CQ_perim deleteAt (count CQ_perim - 1) }; true };   // BACKSPACE
    if (_k in [28, 156]) exitWith { CQ_perimDone = true; true };                                                                      // ENTER
    false
}];
waitUntil { sleep 0.1; CQ_perimDone || { isNull findDisplay 12 } };
removeMissionEventHandler ["MapSingleClick", _click];
if (!isNull findDisplay 12) then { (findDisplay 12) displayRemoveEventHandler ["KeyDown", _key] };
CQ_perimDone = true;
if (count CQ_perim < 3) exitWith { hint "Perimeter needs at least 3 corners" };
private _txt = format ["CQ_basePerimeter = %1;   // %2 corners, base front %3 deg", CQ_perim, count CQ_perim, round CQ_baseDir];
copyToClipboard _txt;
diag_log ("[PERIM] " + _txt);
[_txt] remoteExec ["diag_log", 2];
hint format ["Perimeter with %1 corners exported to the clipboard and the log.", count CQ_perim];
