/*
    CQ_fnc_debugUi  (client, DEBUG only)   F3 or the scroll action "ComQuest debug panel"
    Panel listing every HQ (state, ammo, infantry) with buttons:
    Next phase / +200 ammo / +200 fuel / Destroy HQ (selected HQ), Landing now, Supply flight now,
    Refresh, Close.
    Refreshes itself every 3 s while open.
*/
if (!hasInterface || { !CQ_debug }) exitWith {};
disableSerialization;
if (!isNull (uiNamespace getVariable ["CQ_dbgDisplay", displayNull])) exitWith {};

private _d = (findDisplay 46) createDisplay "RscDisplayEmpty";
uiNamespace setVariable ["CQ_dbgDisplay", _d];

private _x0 = safeZoneX + safeZoneW * 0.02;
private _y0 = safeZoneY + safeZoneH * 0.15;
private _w = safeZoneW * 0.42;
private _h = safeZoneH * 0.70;
private _line = 0.045;

private _bg = _d ctrlCreate ["RscText", -1];
_bg ctrlSetPosition [_x0, _y0, _w, _h];
_bg ctrlSetBackgroundColor [0, 0, 0, 0.82];
_bg ctrlCommit 0;

private _title = _d ctrlCreate ["RscText", -1];
_title ctrlSetPosition [_x0 + 0.01, _y0 + 0.005, _w - 0.02, _line];
_title ctrlSetText "ComQuest DEBUG  -  select an HQ, then a button";
_title ctrlSetTextColor [1, 0.6, 0.2, 1];
_title ctrlCommit 0;

private _status = _d ctrlCreate ["RscText", 9001];
_status ctrlSetPosition [_x0 + 0.01, _y0 + _line, _w - 0.02, _line];
_status ctrlSetText "waiting for the server...";
_status ctrlCommit 0;

private _list = _d ctrlCreate ["RscListBox", 9000];
_list ctrlSetPosition [_x0 + 0.01, _y0 + 2.2 * _line, _w - 0.02, _h - 6 * _line];
_list ctrlCommit 0;

uiNamespace setVariable ["CQ_dbgSel", {
    private _lb = (uiNamespace getVariable ["CQ_dbgDisplay", displayNull]) displayCtrl 9000;
    private _i = lbCurSel _lb;
    if (_i < 0) then { -1 } else { parseNumber (_lb lbData _i) }
}];

// Buttons: 2 rows of 4
private _bw = (_w - 0.05) / 4;
private _by = _y0 + _h - 3.4 * _line;
{
    _x params ["_label", "_cmd", "_row", "_col"];
    private _b = _d ctrlCreate ["RscButton", -1];
    _b ctrlSetPosition [_x0 + 0.01 + _col * (_bw + 0.01), _by + _row * 1.5 * _line, _bw, 1.2 * _line];
    _b ctrlSetText _label;
    _b setVariable ["CQ_cmd", _cmd];
    _b ctrlCommit 0;
    _b ctrlAddEventHandler ["ButtonClick", {
        params ["_ctrl"];
        private _cmd = _ctrl getVariable ["CQ_cmd", "list"];
        if (_cmd == "close") exitWith { (uiNamespace getVariable ["CQ_dbgDisplay", displayNull]) closeDisplay 1 };
        [_cmd, call (uiNamespace getVariable "CQ_dbgSel")] remoteExec ["CQ_fnc_debugCmd", 2];
    }];
} forEach [
    ["Next phase", "next", 0, 0], ["+200 ammo", "ammo", 0, 1], ["Destroy HQ", "destroy", 0, 2], ["Refresh", "list", 0, 3],
    ["Landing now", "root", 1, 0], ["Supply flight now", "flight", 1, 1], ["+200 fuel", "fuel", 1, 2], ["Close", "close", 1, 3]
];

["list", -1] remoteExec ["CQ_fnc_debugCmd", 2];

[] spawn {
    disableSerialization;
    while { !isNull (uiNamespace getVariable ["CQ_dbgDisplay", displayNull]) } do {
        sleep 3;
        ["list", -1] remoteExec ["CQ_fnc_debugCmd", 2];
    };
};
