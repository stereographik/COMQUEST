/*
    CQ_fnc_debugUi  (client)  F3, or the scroll action "Debug panel"
    Who: the host or a logged-in admin (#login) only, also in debug missions (voted admins: no).
    Left: enemy HQ list (select one for the HQ buttons) and a status block.
    Right: buttons by category. Server commands go through CQ_fnc_debugCmd; a few are local
    (map overlays, god mode, arsenal). Toggles show their state in their label.
    Refreshes every 3 s while open.
*/
if (!hasInterface) exitWith {};
if !(isServer || { (call BIS_fnc_admin) == 2 }) exitWith { hint "Debug panel: host or logged-in admin only" };
disableSerialization;
if (!isNull (uiNamespace getVariable ["CQ_dbgDisplay", displayNull])) exitWith {};
call CQ_fnc_debugMap;     // makes sure the map overlay exists (toggles below)
if (isNil "CQ_dbgGod") then { CQ_dbgGod = false };

private _d = (findDisplay 46) createDisplay "RscDisplayEmpty";
uiNamespace setVariable ["CQ_dbgDisplay", _d];
_d displayAddEventHandler ["KeyDown", { params ["_d", "_k"]; if (_k == 22) then { _d closeDisplay 1; true } else { false } }];   // U closes it

// docked on the right, full height, a fifth of the screen wide
private _W = safeZoneW / 5;
private _H = safeZoneH;
private _X = safeZoneX + safeZoneW - _W;
private _Y = safeZoneY;
private _L = 0.036;                                     // line height
private _mk = {
    params ["_cls", "_idc", "_pos", ["_txt", ""]];
    private _c = _d ctrlCreate [[_cls, "CQ_Button"] select (_cls == "RscButton"), _idc];
    [_c, _cls] call CQ_fnc_uiStyle;
    _c ctrlSetPosition _pos;
    if (_txt != "") then { _c ctrlSetText _txt };
    _c ctrlCommit 0;
    _c
};
(["RscText", -1, [_X, _Y, _W, _H]] call _mk) ctrlSetBackgroundColor (CQ_ui get "panel");
(["RscText", -1, [_X, _Y, 0.004, _H]] call _mk) ctrlSetBackgroundColor (CQ_ui get "accent");
private _title = ["RscText", -1, [_X + 0.015, _Y + 0.004, _W * 0.5, _L * 1.1], "COMQUEST DEBUG"] call _mk;
_title ctrlSetFont "PuristaMedium";
_title ctrlSetTextColor (CQ_ui get "accent");
private _close = ["RscButton", -1, [_X + _W - 0.05, _Y + 0.004, 0.04, _L], "X"] call _mk;
_close ctrlAddEventHandler ["ButtonClick", { (uiNamespace getVariable ["CQ_dbgDisplay", displayNull]) closeDisplay 1 }];

// ---- top: status + HQ list
private _lw = _W - 0.027;
private _status = ["RscStructuredText", 9001, [_X + 0.015, _Y + _L * 1.2, _lw, _L * 4.4]] call _mk;
_status ctrlSetBackgroundColor (CQ_ui get "inset");
private _lt = ["RscText", -1, [_X + 0.015, _Y + _L * 5.7, _lw, _L * 0.7], "ENEMY HQs  (select one for the HQ buttons)"] call _mk;
_lt ctrlSetTextColor (CQ_ui get "muted");
_lt ctrlSetFontHeight (_L * 0.6);
private _list = ["RscListBox", 9000, [_X + 0.015, _Y + _L * 6.4, _lw, _L * 4.8]] call _mk;
_list ctrlSetFontHeight (_L * 0.62);

uiNamespace setVariable ["CQ_dbgSel", {
    private _lb = (uiNamespace getVariable ["CQ_dbgDisplay", displayNull]) displayCtrl 9000;
    private _i = lbCurSel _lb;
    if (_i < 0) then { -1 } else { parseNumber (_lb lbData _i) }
}];

// ---- right: categories of buttons
// [label, command]; command "!x" = local action, else sent to the server
// [category, [[subcategory, [[label, command], ...]], ...]]; command "!x" = local action, else sent to the server
private _cats = [
    ["TELEPORTERS", [
        ["Teleport", [["Near HQ", "tpHq"], ["Radio tower", "tpTower"], ["Build truck", "tpBt"], ["Relay vehicle", "tpRelayVeh"], ["Log my position", "logPos"], ["Crash site", "tpCrash"], ["Hostage", "tpHst"], ["Outpost", "tpOp"], ["Base", "tpBase"]]]
    ]],
    ["MAP VISIBILITY", [
        ["Show", [["Enemies", "!mapEnemy"], ["Friendlies", "!mapFriend"], ["HQ sites", "!mapHq"]]]
    ]],
    ["ENEMY HQ  (selected in the list)", [
        ["Phase", [["FULL HQ NOW", "fullHq"], ["Next phase", "next"], ["+200 ammo", "ammo"], ["+200 fuel", "fuel"], ["Reinf. wave", "wave"]]],
        ["Objectives", [["Kill cmdr", "killCmd"], ["Capture cmdr", "capture"], ["Hack tower", "hack"], ["Destroy tower", "tower"],
                        ["Destroy depot", "depot"], ["Destroy tanker", "tanker"], ["Destroy HQ", "destroy"]]],
        ["Build truck", [["Kill truck", "btKill"], ["Replacement now", "btNow"]]]
    ]],
    ["ENEMY FORCES", [
        ["Carrier", [["Landing now", "root"], ["Supply flight", "flight"], ["Carrier -1 HQ", "carrierMinus"], ["Carrier full", "carrierFull"]]],
        ["Forces", [["Kill all enemies", "killAll"], ["Full power", "!fullPower"]]]
    ]],
    ["EVENTS", [
        ["Crash", [["Trigger crash", "crash"], ["Timer out", "crashOut"], ["Decrypt now", "decrypt"]]],
        ["Outpost", [["Build", "opBuild"], ["Jammer off", "opJam"], ["Destroy", "opKill"]]],
        ["Hostage", [["Start hostage", "hst"], ["Clear house", "hstClear"], ["Firmware now", "hstFw"],
                     ["Into the heli", "hstBoard"], ["Home now", "hstHome"], ["End event", "hstEnd"]]]
    ]],
    ["FRIENDLY", [
        ["MAGPIE", [["Report now", "magReport"], ["Launch missing", "magLaunch"], ["Shoot down", "magKill"]]],
        ["Player", [["Heal me", "heal"], ["God mode", "!god"], ["Arsenal", "!arsenal"], ["+500 points", "points"], ["Fix vehicle", "vehFix"]]],
        ["Base", [["Depot reset", "vehReset"], ["Rebuild def.", "defRebuild"]]]
    ]],
    ["WORLD & STORY", [
        ["Time, weather", [["+1 hour", "time1"], ["Noon", "noon"], ["Night", "night"], ["Clear weather", "clearWx"]]],
        ["Story", [["Next act", "actNext"], ["SITREP now", "sitrep"], ["Reset speech", "storyReset"]]]
    ]],
    ["LOGS & VIEW", [
        ["Logs, view", [["Enemy logs", "!logEnemy"], ["Friendly logs", "!logFriend"], ["PLAYER VIEW", "!playerView"]]]
    ]]
];
// ---- below: the buttons, sized to fit the free height (no scrollbar): a subcategory label column,
// then 3 small buttons per row
private _top = _Y + _L * 11.5;
private _rowsN = 0; private _subsN = 0;
{ { _rowsN = _rowsN + ceil (count (_x select 1) / 3); _subsN = _subsN + 1 } forEach (_x select 1) } forEach _cats;
private _u = (((_Y + _H - 0.01) - _top) / (_rowsN + 1.35 * count _cats + 0.15 * _subsN)) min 0.03;   // one row
private _fh = _u * 0.78;                                   // font height
private _rx = _X + 0.012;
private _rw = _W - 0.02;
private _sw = _rw * 0.2;
private _cols = 3;
private _bw = (_rw - _sw - (_cols - 1) * 0.004) / _cols;
private _y = _top;
private _toggles = [];
{
    _x params ["_cat", "_subs"];
    private _h = ["RscText", -1, [_rx, _y, _rw, _u], _cat] call _mk;
    _h ctrlSetFont "PuristaMedium";
    _h ctrlSetFontHeight _fh;
    _h ctrlSetTextColor (CQ_ui get "accent");
    (["RscText", -1, [_rx, _y + _u, _rw, 0.002]] call _mk) ctrlSetBackgroundColor (CQ_ui get "accent");
    _y = _y + _u * 1.15;
    {
        _x params ["_sub", "_btns"];
        private _sl = ["RscText", -1, [_rx, _y, _sw, _u * 0.95], _sub] call _mk;
        _sl ctrlSetTextColor (CQ_ui get "muted");
        _sl ctrlSetFontHeight (_fh * 0.9);
        {
            _x params ["_label", "_cmd"];
            private _c = _forEachIndex mod _cols;
            if (_c == 0 && { _forEachIndex > 0 }) then { _y = _y + _u };
            private _b = ["RscButton", -1, [_rx + _sw + _c * (_bw + 0.004), _y, _bw, _u * 0.92], _label] call _mk;
            _b ctrlSetFontHeight _fh;
            _b setVariable ["CQ_cmd", _cmd];
            _b setVariable ["CQ_label", _label];
            if ((_cmd select [0, 1]) == "!" && { _cmd != "!arsenal" }) then { _toggles pushBack _b };
            _b ctrlAddEventHandler ["ButtonClick", {
                params ["_ctrl"];
                private _cmd = _ctrl getVariable ["CQ_cmd", ""];
                switch (_cmd) do {
                    case "!mapEnemy": { CQ_dbgShowEnemy = !CQ_dbgShowEnemy };
                    case "!mapFriend": { CQ_dbgShowFriend = !CQ_dbgShowFriend };
                    case "!mapHq": { CQ_dbgShowHq = !CQ_dbgShowHq };
                    case "!fullPower": {
                        private _on = !(missionNamespace getVariable ["CQ_testFullPower", false]);
                        CQ_testFullPower = _on;        // label right away; the server applies it
                        ["fullPower", [0, 1] select _on] remoteExec ["CQ_fnc_debugCmd", 2];
                    };
                    case "!logEnemy";
                    case "!logFriend": {
                        private _f = +(missionNamespace getVariable ["CQ_myLogs", [false, false]]);
                        private _i = [0, 1] select (_cmd == "!logFriend");
                        _f set [_i, !(_f select _i)];
                        CQ_myLogs = _f;                // label right away; the server answers with the same value
                        ["logs", ([0, 1] select (_f select 0)) + ([0, 2] select (_f select 1))] remoteExec ["CQ_fnc_debugCmd", 2];
                    };
                    case "!god": { CQ_dbgGod = !CQ_dbgGod; player allowDamage !CQ_dbgGod; if (vehicle player != player) then { (vehicle player) allowDamage !CQ_dbgGod } };
                    case "!playerView": {
                        private _on = !(missionNamespace getVariable ["CQ_playerView", false]);
                        if (_on) then { CQ_dbgShowEnemy = false; CQ_dbgShowFriend = false; CQ_dbgShowHq = false; CQ_dbgGod = false; player allowDamage true };
                        CQ_playerView = _on;       // label right away; the server publishes the same value
                        ["playerView", [0, 1] select _on] remoteExec ["CQ_fnc_debugCmd", 2];
                    };
                    case "!arsenal": { (uiNamespace getVariable ["CQ_dbgDisplay", displayNull]) closeDisplay 1; ["Open", true] spawn BIS_fnc_arsenal };
                    default { [_cmd, call (uiNamespace getVariable "CQ_dbgSel")] remoteExec ["CQ_fnc_debugCmd", 2] };
                };
                call (uiNamespace getVariable ["CQ_dbgToggleLabels", {}]);
            }];
        } forEach _btns;
        _y = _y + _u * 1.15;
    } forEach _subs;
    _y = _y + _u * 0.2;
} forEach _cats;
uiNamespace setVariable ["CQ_dbgToggles", _toggles];
uiNamespace setVariable ["CQ_dbgToggleLabels", {
    {
        private _cmd = _x getVariable ["CQ_cmd", ""];
        private _on = switch (_cmd) do {
            case "!mapEnemy": { CQ_dbgShowEnemy };
            case "!mapFriend": { CQ_dbgShowFriend };
            case "!mapHq": { CQ_dbgShowHq };
            case "!fullPower": { missionNamespace getVariable ["CQ_testFullPower", false] };
            case "!logEnemy": { (missionNamespace getVariable ["CQ_myLogs", [false, false]]) select 0 };
            case "!logFriend": { (missionNamespace getVariable ["CQ_myLogs", [false, false]]) select 1 };
            case "!god": { CQ_dbgGod };
            case "!playerView": { missionNamespace getVariable ["CQ_playerView", false] };
            default { false };
        };
        _x ctrlSetText format ["%1: %2", _x getVariable ["CQ_label", ""], ["OFF", "ON"] select _on];
        _x ctrlSetTextColor ([(CQ_ui get "muted"), [0.55, 0.95, 0.45, 1]] select _on);
    } forEach (uiNamespace getVariable ["CQ_dbgToggles", []]);
}];
call (uiNamespace getVariable "CQ_dbgToggleLabels");

["list", -1] remoteExec ["CQ_fnc_debugCmd", 2];
[] spawn {
    disableSerialization;
    while { !isNull (uiNamespace getVariable ["CQ_dbgDisplay", displayNull]) } do {
        sleep 3;
        ["list", -1] remoteExec ["CQ_fnc_debugCmd", 2];
    };
};
