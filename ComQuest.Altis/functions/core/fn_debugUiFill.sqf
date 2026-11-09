/*
    CQ_fnc_debugUiFill  (client, answer of CQ_fnc_debugCmd)
    [_rows, _message, _status]: refreshes the panel list (keeps the selection) and status line.
*/
params [["_rows", []], ["_msg", ""], ["_status", ""]];
disableSerialization;

if (_msg != "") then { systemChat format ["[CQ debug] %1", _msg] };

CQ_dbgHqList = _rows;     // HQ sites for the map overlay (CQ_fnc_debugMap)
private _d = uiNamespace getVariable ["CQ_dbgDisplay", displayNull];
if (isNull _d) exitWith {};

private _lb = _d displayCtrl 9000;
private _prev = if (lbCurSel _lb >= 0) then { _lb lbData (lbCurSel _lb) } else { "" };
lbClear _lb;
{
    _x params ["_id", "_txt"];
    private _i = _lb lbAdd _txt;
    _lb lbSetData [_i, str _id];
    if (str _id == _prev) then { _lb lbSetCurSel _i };
} forEach _rows;
if (_rows isEqualTo []) then { _lb lbAdd "No HQ yet - press 'Landing now'" };

(_d displayCtrl 9001) ctrlSetStructuredText parseText _status;
